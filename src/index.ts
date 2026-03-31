/**
 * Cloudflare Workers API for Car Library
 * Phase 1: Basic CRUD operations for posts and car master data
 * Phase 2: Image upload with R2
 * Phase 3: AI-powered license plate detection and masking
 */

export interface Env {
  DB: D1Database;
  CAR_IMAGES: R2Bucket;
  AI: Ai;
}

import { uploadAndMaskImage, maskImageRegions, detectLicensePlates } from './image-processing';

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

      // ========== 画像アップロード関連のエンドポイント ==========

      // POST /detect - AIでナンバープレート検出のみ（アップロードなし）
      if (path === '/detect' && method === 'POST') {
        const contentType = request.headers.get('content-type') || '';
        
        if (!contentType.includes('multipart/form-data')) {
          return errorResponse('Content-Type must be multipart/form-data');
        }

        try {
          const formData = await request.formData();
          const fileEntry = formData.get('file');
          
          if (!fileEntry || typeof fileEntry === 'string') {
            return errorResponse('No file provided');
          }

          const file = fileEntry as File;
          const arrayBuffer = await file.arrayBuffer();

          console.log('[Detect] Running AI detection...');
          const detectedBoxes = await detectLicensePlates(
            { AI: env.AI },
            arrayBuffer
          );
          
          console.log('[Detect] Found', detectedBoxes.length, 'regions');

          return jsonResponse({
            message: 'Detection completed',
            detectedBoxes,
            detectedCount: detectedBoxes.length,
          }, 200);
        } catch (error) {
          console.error('Detection error:', error);
          return errorResponse(`Detection failed: ${error}`);
        }
      }

      // POST /upload - 画像アップロード（オプションでAIマスキングまたは手動領域指定）
      if (path === '/upload' && method === 'POST') {
        const contentType = request.headers.get('content-type') || '';
        
        if (!contentType.includes('multipart/form-data')) {
          return errorResponse('Content-Type must be multipart/form-data');
        }

        try {
          const formData = await request.formData();
          const fileEntry = formData.get('file');
          const enableMasking = url.searchParams.get('mask') === 'true';
          const maskingRectsJson = formData.get('maskingRects');
          
          console.log('[Upload] enableMasking:', enableMasking);
          console.log('[Upload] maskingRectsJson:', maskingRectsJson);
          
          if (!fileEntry || typeof fileEntry === 'string') {
            return errorResponse('No file provided');
          }

          const file = fileEntry as File;
          const arrayBuffer = await file.arrayBuffer();

          let imageUrl: string;
          let originalImageUrl: string | undefined;
          let detectedCount = 0;
          let detectedBoxes: any[] = [];

          // 手動指定のマスキング領域がある場合（優先）
          if (maskingRectsJson && typeof maskingRectsJson === 'string') {
            console.log('[Upload] Using manual masking...');
            try {
              const manualBoxes = JSON.parse(maskingRectsJson) as Array<{x: number; y: number; width: number; height: number}>;
              console.log('[Upload] Parsed manual boxes:', manualBoxes);
              
              const timestamp = Date.now();
              const randomStr = Math.random().toString(36).substring(2, 15);
              const fileExt = file.name.split('.').pop() || 'jpg';
              const baseFileName = `${timestamp}-${randomStr}`;
              
              if (manualBoxes.length === 0) {
                // 空配列の場合はマスキングなしでアップロード
                console.log('[Upload] Manual boxes empty, uploading without masking');
                const key = `uploads/${baseFileName}.${fileExt}`;
                await env.CAR_IMAGES.put(key, arrayBuffer);
                
                return jsonResponse({
                  message: 'Image uploaded without masking (manual empty)',
                  imageUrl: `/images/${key}`,
                  detectedCount: 0,
                  detectedBoxes: [],
                  masked: false,
                }, 201);
              }
              
              // 元画像を保存
              const originalKey = `uploads/original/${baseFileName}.${fileExt}`;
              await env.CAR_IMAGES.put(originalKey, arrayBuffer);
              console.log('[Upload] Original image saved:', originalKey);
              
              // 手動指定領域でマスキング
              const maskedData = await maskImageRegions(arrayBuffer, manualBoxes);
              const maskedKey = `uploads/masked/${baseFileName}.${fileExt}`;
              await env.CAR_IMAGES.put(maskedKey, maskedData);
              console.log('[Upload] Masked image saved:', maskedKey);
              
              return jsonResponse({
                message: 'Image uploaded with manual masking',
                imageUrl: `/images/${maskedKey}`,
                originalImageUrl: `/images/${originalKey}`,
                detectedCount: manualBoxes.length,
                detectedBoxes: manualBoxes,
                masked: true,
              }, 201);
            } catch (e) {
              console.error('[Upload] Failed to process manual masking:', e);
              // エラーの場合はそのままエラーを返す（AIマスキングにフォールバックしない）
              return errorResponse(`Failed to process manual masking: ${e}`);
            }
          }

          console.log('[Upload] No manual masking rects, checking AI masking...');
          if (enableMasking) {
            // AIマスキングを実行
            console.log('[Upload] Using AI masking...');
            const result = await uploadAndMaskImage(
              { AI: env.AI, CAR_IMAGES: env.CAR_IMAGES },
              arrayBuffer,
              file.name
            );
            
            imageUrl = result.maskedUrl;
            originalImageUrl = result.originalUrl;
            detectedCount = result.detectedCount;
            detectedBoxes = result.detectedBoxes;
          } else {
            // 通常のアップロード（マスキングなし）
            const timestamp = Date.now();
            const randomStr = Math.random().toString(36).substring(2, 15);
            const fileExt = file.name.split('.').pop() || 'jpg';
            const fileName = `${timestamp}-${randomStr}.${fileExt}`;
            const key = `uploads/${fileName}`;

            await env.CAR_IMAGES.put(key, arrayBuffer, {
              httpMetadata: {
                contentType: file.type,
              },
            });

            imageUrl = `/images/${key}`;
          }

          return jsonResponse({
            message: 'Image uploaded successfully',
            imageUrl,
            originalImageUrl,
            detectedCount,
            detectedBoxes,
            masked: enableMasking,
          }, 201);
        } catch (error) {
          console.error('Upload error:', error);
          return errorResponse('Failed to upload image', 500);
        }
      }

      // GET /images/* - R2から画像を取得
      if (path.startsWith('/images/') && method === 'GET') {
        const key = path.replace('/images/', '');
        
        try {
          const object = await env.CAR_IMAGES.get(key);
          
          if (object === null) {
            return errorResponse('Image not found', 404);
          }

          const headers = new Headers();
          object.writeHttpMetadata(headers);
          headers.set('etag', object.httpEtag);
          headers.set('cache-control', 'public, max-age=31536000');
          headers.append('Access-Control-Allow-Origin', '*');

          return new Response(object.body, { headers });
        } catch (error) {
          console.error('Image fetch error:', error);
          return errorResponse('Failed to fetch image', 500);
        }
      }

      // 404 Not Found
      return errorResponse('Endpoint not found', 404);

    } catch (error) {
      console.error('Error:', error);
      return errorResponse('Internal server error', 500);
    }
  },
};
