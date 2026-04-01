import { uploadAndMaskImage, maskImageRegions, detectLicensePlates, resizeImage } from './image-processing';
import { extractBearerToken, generateJWT, verifyJWT, hashPassword, verifyPassword } from './auth';

export interface Env {
  DB: D1Database;
  CAR_IMAGES: R2Bucket;
  AI: Ai;
  JWT_SECRET: string;
}

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
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

async function requireAuth(request: Request, env: Env): Promise<string | null> {
  const token = extractBearerToken(request.headers.get('Authorization'));
  if (!token) {
    return null;
  }
  const payload = await verifyJWT(token, env.JWT_SECRET);
  return payload?.userId ?? null;
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

      // ========== 自分の投稿一覧取得 ==========

      if (path === '/users/me/posts' && method === 'GET') {
        const userId = await requireAuth(request, env);
        if (!userId) {
          return errorResponse('Unauthorized', 401);
        }

        const { results } = await env.DB.prepare(
          'SELECT * FROM posts WHERE user_id = ? AND deleted_at IS NULL ORDER BY created_at DESC'
        ).bind(userId).all();
        return jsonResponse({ posts: results });
      }

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
        return jsonResponse({ posts: results, limit, offset });
      }

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

      if (path === '/posts' && method === 'POST') {
        const userId = await requireAuth(request, env);
        if (!userId) {
          return errorResponse('Unauthorized', 401);
        }

        const body = await request.json() as any;
        const { car_maker, car_model, car_variant, image_url, description } = body;

        if (!car_maker || !car_model || !image_url) {
          return errorResponse('Missing required fields: car_maker, car_model, image_url');
        }

        const result = await env.DB.prepare(
          `INSERT INTO posts (user_id, car_maker, car_model, car_variant, image_url, description)
           VALUES (?, ?, ?, ?, ?, ?)`
        ).bind(
          userId,
          car_maker,
          car_model,
          car_variant || null,
          image_url,
          description || null
        ).run();

        return jsonResponse({
          message: 'Post created successfully',
          id: result.meta.last_row_id,
        }, 201);
      }

      if (path.match(/^\/posts\/\d+$/) && method === 'PATCH') {
        const userId = await requireAuth(request, env);
        if (!userId) {
          return errorResponse('Unauthorized', 401);
        }

        const id = path.split('/')[2];
        const { results: existing } = await env.DB.prepare(
          'SELECT user_id FROM posts WHERE id = ? AND deleted_at IS NULL'
        ).bind(id).all();

        if (existing.length === 0) {
          return errorResponse('Post not found', 404);
        }
        if ((existing[0] as any).user_id !== userId) {
          return errorResponse('Forbidden', 403);
        }

        const body = await request.json() as any;
        const description = body?.description !== undefined ? body.description : undefined;
        const carVariant = body?.car_variant !== undefined ? body.car_variant : undefined;
        const carMaker = body?.car_maker !== undefined ? body.car_maker : undefined;
        const carModel = body?.car_model !== undefined ? body.car_model : undefined;

        if (description === undefined && carVariant === undefined && carMaker === undefined && carModel === undefined) {
          return errorResponse('更新するフィールドがありません', 400);
        }

        const fields: string[] = [];
        const values: unknown[] = [];
        if (carMaker !== undefined) {
          if (!carMaker) return errorResponse('car_makerは必須です', 400);
          fields.push('car_maker = ?');
          values.push(carMaker);
        }
        if (carModel !== undefined) {
          if (!carModel) return errorResponse('car_modelは必須です', 400);
          fields.push('car_model = ?');
          values.push(carModel);
        }
        if (description !== undefined) {
          fields.push('description = ?');
          values.push(description || null);
        }
        if (carVariant !== undefined) {
          fields.push('car_variant = ?');
          values.push(carVariant || null);
        }

        await env.DB.prepare(
          `UPDATE posts SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = ?`
        ).bind(...values, id).run();

        return jsonResponse({ message: 'Post updated successfully' });
      }

      if (path.match(/^\/posts\/\d+$/) && method === 'DELETE') {
        const userId = await requireAuth(request, env);
        if (!userId) {
          return errorResponse('Unauthorized', 401);
        }

        const id = path.split('/')[2];
        const { results } = await env.DB.prepare(
          'SELECT user_id FROM posts WHERE id = ? AND deleted_at IS NULL'
        ).bind(id).all();

        if (results.length === 0) {
          return errorResponse('Post not found', 404);
        }
        if ((results[0] as any).user_id !== userId) {
          return errorResponse('Forbidden', 403);
        }

        const result = await env.DB.prepare(
          'UPDATE posts SET deleted_at = CURRENT_TIMESTAMP WHERE id = ? AND deleted_at IS NULL'
        ).bind(id).run();

        if (result.meta.changes === 0) {
          return errorResponse('Post not found or already deleted', 404);
        }

        return jsonResponse({ message: 'Post deleted successfully' });
      }

      // ========== 認証関連のエンドポイント ==========

      if (path === '/auth/register' && method === 'POST') {
        const body = await request.json() as any;
        const userId = String(body?.userId || '').trim();
        const password = String(body?.password || '');

        if (!userId || !password) {
          return errorResponse('userId と password は必須です', 400);
        }
        if (userId.length < 3 || userId.length > 30) {
          return errorResponse('userIdは3〜30文字にしてください', 400);
        }
        if (!/^[a-zA-Z0-9_-]+$/.test(userId)) {
          return errorResponse('userIdに使えるのは英数字・ハイフン・アンダースコアのみです', 400);
        }
        if (password.length < 8) {
          return errorResponse('パスワードは8文字以上にしてください', 400);
        }

        const existing = await env.DB.prepare(
          'SELECT user_id FROM users WHERE user_id = ?'
        ).bind(userId).first();
        if (existing) {
          return errorResponse('そのユーザーIDはすでに使われています', 409);
        }

        const passwordHash = await hashPassword(password);
        await env.DB.prepare(
          'INSERT INTO users (user_id, password_hash) VALUES (?, ?)'
        ).bind(userId, passwordHash).run();

        const token = await generateJWT(userId, env.JWT_SECRET);
        return jsonResponse({ token, userId }, 201);
      }

      if (path === '/auth/login' && method === 'POST') {
        const body = await request.json() as any;
        const userId = String(body?.userId || '').trim();
        const password = String(body?.password || '');

        if (!userId || !password) {
          return errorResponse('userId と password は必須です', 400);
        }

        const user = await env.DB.prepare(
          'SELECT user_id, password_hash FROM users WHERE user_id = ?'
        ).bind(userId).first() as { user_id: string; password_hash: string } | null;

        if (!user) {
          return errorResponse('ユーザーIDまたはパスワードが正しくありません', 401);
        }

        const ok = await verifyPassword(password, user.password_hash);
        if (!ok) {
          return errorResponse('ユーザーIDまたはパスワードが正しくありません', 401);
        }

        const token = await generateJWT(userId, env.JWT_SECRET);
        return jsonResponse({ token, userId });
      }

      if (path === '/auth/me' && method === 'GET') {
        const userId = await requireAuth(request, env);
        if (!userId) {
          return errorResponse('Unauthorized', 401);
        }
        return jsonResponse({ userId });
      }

      // ========== 画像アップロード関連のエンドポイント ==========

      if (path === '/detect' && method === 'POST') {
        const userId = await requireAuth(request, env);
        if (!userId) {
          return errorResponse('Unauthorized', 401);
        }

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

          const detectedBoxes = await detectLicensePlates({ AI: env.AI }, arrayBuffer);
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

      if (path === '/upload' && method === 'POST') {
        const userId = await requireAuth(request, env);
        if (!userId) {
          return errorResponse('Unauthorized', 401);
        }

        const contentType = request.headers.get('content-type') || '';
        if (!contentType.includes('multipart/form-data')) {
          return errorResponse('Content-Type must be multipart/form-data');
        }

        try {
          const formData = await request.formData();
          const fileEntry = formData.get('file');
          const enableMasking = url.searchParams.get('mask') === 'true';
          const maskingRectsJson = formData.get('maskingRects');

          if (!fileEntry || typeof fileEntry === 'string') {
            return errorResponse('No file provided');
          }

          const file = fileEntry as File;
          const arrayBuffer = await file.arrayBuffer();

          let imageUrl: string;
          let originalImageUrl: string | undefined;
          let detectedCount = 0;
          let detectedBoxes: any[] = [];

          if (maskingRectsJson && typeof maskingRectsJson === 'string') {
            try {
              const manualBoxes = JSON.parse(maskingRectsJson) as Array<{ x: number; y: number; width: number; height: number }>;

              const timestamp = Date.now();
              const randomStr = Math.random().toString(36).substring(2, 15);
              const fileExt = file.name.split('.').pop() || 'jpg';
              const baseFileName = `${timestamp}-${randomStr}`;

              if (manualBoxes.length === 0) {
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

              const originalKey = `uploads/original/${baseFileName}.${fileExt}`;
              await env.CAR_IMAGES.put(originalKey, arrayBuffer);

              const maskedData = await maskImageRegions(arrayBuffer, manualBoxes);
              const maskedKey = `uploads/masked/${baseFileName}.${fileExt}`;
              await env.CAR_IMAGES.put(maskedKey, maskedData);

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
              return errorResponse(`Failed to process manual masking: ${e}`);
            }
          }

          if (enableMasking) {
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

      if (path.startsWith('/images/') && method === 'GET') {
        const key = path.replace('/images/', '');
        const widthParam = url.searchParams.get('w');
        const qualityParam = url.searchParams.get('q');
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

          // ?w= パラメータなし → オリジナルをそのまま返す
          if (!widthParam) {
            return new Response(object.body, { headers });
          }

          // ?w= 指定あり → Photon でリサイズして返す
          const width = Math.min(Math.max(parseInt(widthParam) || 800, 100), 2000);
          const quality = Math.min(Math.max(parseInt(qualityParam || '80'), 20), 95);

          const imageData = await object.arrayBuffer();
          const resized = await resizeImage(imageData, width, quality);

          headers.set('content-type', 'image/jpeg');
          return new Response(resized, { headers });
        } catch (error) {
          console.error('Image fetch error:', error);
          return errorResponse('Failed to fetch image', 500);
        }
      }

      return errorResponse('Endpoint not found', 404);
    } catch (error) {
      console.error('Error:', error);
      return errorResponse('Internal server error', 500);
    }
  },
};
