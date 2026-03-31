/**
 * Cloudflare Workers API for Car Library
 * Phase 1: Basic CRUD operations for posts and car master data
 */

export interface Env {
  DB: D1Database;
}

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

// レスポンスヘルパー
function jsonResponse(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders,
    },
  });
}

function errorResponse(message: string, status = 400) {
  return jsonResponse({ error: message }, status);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // CORS preflight request
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    try {
      // ========== 投稿関連のエンドポイント ==========
      
      // GET /posts - 投稿一覧取得
      if (path === '/posts' && method === 'GET') {
        const limit = parseInt(url.searchParams.get('limit') || '20');
        const offset = parseInt(url.searchParams.get('offset') || '0');
        const maker = url.searchParams.get('maker');
        const model = url.searchParams.get('model');

        let query = 'SELECT * FROM posts WHERE deleted_at IS NULL';
        const params: any[] = [];

        if (maker) {
          query += ' AND car_maker = ?';
          params.push(maker);
        }
        if (model) {
          query += ' AND car_model = ?';
          params.push(model);
        }

        query += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
        params.push(limit, offset);

        const { results } = await env.DB.prepare(query).bind(...params).all();
        
        return jsonResponse({
          posts: results,
          limit,
          offset,
        });
      }

      // GET /posts/:id - 投稿詳細取得
      if (path.match(/^\/posts\/\d+$/) && method === 'GET') {
        const id = path.split('/')[2];
        const { results } = await env.DB.prepare(
          'SELECT * FROM posts WHERE id = ? AND deleted_at IS NULL'
        ).bind(id).all();

        if (results.length === 0) {
          return errorResponse('Post not found', 404);
        }

        return jsonResponse({ post: results[0] });
      }

      // POST /posts - 新規投稿作成
      if (path === '/posts' && method === 'POST') {
        const body = await request.json() as any;
        const { user_id, car_maker, car_model, car_variant, image_url, description, is_own_car } = body;

        if (!user_id || !car_maker || !car_model || !image_url) {
          return errorResponse('Missing required fields: user_id, car_maker, car_model, image_url');
        }

        const result = await env.DB.prepare(
          `INSERT INTO posts (user_id, car_maker, car_model, car_variant, image_url, description, is_own_car)
           VALUES (?, ?, ?, ?, ?, ?, ?)`
        ).bind(
          user_id,
          car_maker,
          car_model,
          car_variant || null,
          image_url,
          description || null,
          is_own_car ? 1 : 0
        ).run();

        return jsonResponse({
          message: 'Post created successfully',
          id: result.meta.last_row_id,
        }, 201);
      }

      // DELETE /posts/:id - 投稿削除（論理削除）
      if (path.match(/^\/posts\/\d+$/) && method === 'DELETE') {
        const id = path.split('/')[2];
        
        // TODO: Phase 4で認証実装後、user_idの照合を追加
        const result = await env.DB.prepare(
          'UPDATE posts SET deleted_at = CURRENT_TIMESTAMP WHERE id = ? AND deleted_at IS NULL'
        ).bind(id).run();

        if (result.meta.changes === 0) {
          return errorResponse('Post not found or already deleted', 404);
        }

        return jsonResponse({ message: 'Post deleted successfully' });
      }

      // ========== 車種マスター関連のエンドポイント ==========

      // GET /cars - 車種マスター取得
      if (path === '/cars' && method === 'GET') {
        const maker = url.searchParams.get('maker');
        const search = url.searchParams.get('search');

        let query = 'SELECT * FROM cars_master';
        const params: any[] = [];

        if (maker) {
          query += ' WHERE maker = ?';
          params.push(maker);
        } else if (search) {
          query += ' WHERE maker LIKE ? OR model LIKE ?';
          params.push(`%${search}%`, `%${search}%`);
        }

        query += ' ORDER BY maker, model, year_from DESC';

        const { results } = await env.DB.prepare(query).bind(...params).all();
        
        return jsonResponse({ cars: results });
      }

      // GET /cars/makers - メーカー一覧取得
      if (path === '/cars/makers' && method === 'GET') {
        const { results } = await env.DB.prepare(
          'SELECT DISTINCT maker FROM cars_master ORDER BY maker'
        ).all();

        return jsonResponse({ makers: results.map((r: any) => r.maker) });
      }

      // 404 Not Found
      return errorResponse('Endpoint not found', 404);

    } catch (error) {
      console.error('Error:', error);
      return errorResponse('Internal server error', 500);
    }
  },
};
