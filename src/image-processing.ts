/**
 * 画像処理ユーティリティ
 * ナンバープレートのマスキング処理
 */

import { PhotonImage } from '@cf-wasm/photon/workerd';

/**
 * 画像上の矩形領域をブラーでマスキング
 * @param imageData 画像データ（ArrayBuffer）
 * @param boxes マスキングする矩形領域の配列 [{x, y, width, height}]
 * @returns マスキング済み画像データ
 */
export async function maskImageRegions(
  imageData: ArrayBuffer,
  boxes: Array<{ x: number; y: number; width: number; height: number }>
): Promise<ArrayBuffer> {
  if (boxes.length === 0) {
    console.log('No regions to mask');
    return imageData;
  }

  try {
    // PhotonImageを作成
    const inputBytes = new Uint8Array(imageData);
    const img = PhotonImage.new_from_byteslice(inputBytes);
    
    const width = img.get_width();
    const height = img.get_height();
    
    console.log(`Image dimensions: ${width}x${height}, masking ${boxes.length} regions`);
    
    // 生のピクセルデータを取得（RGBA形式）
    const rawPixels = img.get_raw_pixels();
    
    // 元のピクセルデータのコピーを作成（ブラー処理の読み取り用）
    const originalPixels = new Uint8Array(rawPixels);
    
    // 各検出領域にセパラブルボックスブラーを適用
    const blurRadius = 15;
    
    for (const box of boxes) {
      const startX = Math.max(0, Math.floor(box.x));
      const startY = Math.max(0, Math.floor(box.y));
      const endX = Math.min(width, Math.ceil(box.x + box.width));
      const endY = Math.min(height, Math.ceil(box.y + box.height));
      
      console.log(`Blurring region: (${startX}, ${startY}) to (${endX}, ${endY})`);
      
      const regionWidth = endX - startX;
      const regionHeight = endY - startY;
      
      // 横方向パス: originalPixels -> tempPixels
      const tempPixels = new Uint8Array(regionWidth * regionHeight * 4);
      
      for (let y = startY; y < endY; y++) {
        for (let x = startX; x < endX; x++) {
          let r = 0, g = 0, b = 0, count = 0;
          for (let dx = -blurRadius; dx <= blurRadius; dx++) {
            const nx = Math.min(Math.max(x + dx, 0), width - 1);
            const idx = (y * width + nx) * 4;
            r += originalPixels[idx];
            g += originalPixels[idx + 1];
            b += originalPixels[idx + 2];
            count++;
          }
          const tempIdx = ((y - startY) * regionWidth + (x - startX)) * 4;
          tempPixels[tempIdx]     = Math.round(r / count);
          tempPixels[tempIdx + 1] = Math.round(g / count);
          tempPixels[tempIdx + 2] = Math.round(b / count);
          tempPixels[tempIdx + 3] = 255;
        }
      }
      
      // 縦方向パス: tempPixels -> rawPixels
      for (let y = startY; y < endY; y++) {
        for (let x = startX; x < endX; x++) {
          let r = 0, g = 0, b = 0, count = 0;
          for (let dy = -blurRadius; dy <= blurRadius; dy++) {
            const ny = Math.min(Math.max(y + dy, startY), endY - 1);
            const tempIdx = ((ny - startY) * regionWidth + (x - startX)) * 4;
            r += tempPixels[tempIdx];
            g += tempPixels[tempIdx + 1];
            b += tempPixels[tempIdx + 2];
            count++;
          }
          const index = (y * width + x) * 4;
          rawPixels[index]     = Math.round(r / count);
          rawPixels[index + 1] = Math.round(g / count);
          rawPixels[index + 2] = Math.round(b / count);
        }
      }
    }
    
    // マスキング済みのピクセルデータから新しいPhotonImageを作成
    const maskedImg = new PhotonImage(rawPixels, width, height);
    
    // JPEG形式でエンコード（元のフォーマットを維持したい場合は調整）
    const outputBytes = maskedImg.get_bytes_jpeg(85); // quality: 85
    
    // メモリ解放
    img.free();
    maskedImg.free();
    
    console.log(`Masking completed. Output size: ${outputBytes.length} bytes`);
    return outputBytes.buffer as ArrayBuffer;
    
  } catch (error) {
    console.error('Masking error:', error);
    // エラー時は元の画像を返す
    return imageData;
  }
}

/**
 * Workers AIを使用してナンバープレートを検出
 * @param env Cloudflare環境変数
 * @param imageData 画像データ
 * @returns 検出されたナンバープレートの位置情報（ピクセル座標）
 */
export async function detectLicensePlates(
  env: { AI: Ai },
  imageData: ArrayBuffer
): Promise<Array<{ x: number; y: number; width: number; height: number }>> {
  try {
    // 画像サイズを取得
    const inputBytes = new Uint8Array(imageData);
    const img = PhotonImage.new_from_byteslice(inputBytes);
    const imageWidth = img.get_width();
    const imageHeight = img.get_height();
    img.free(); // メモリ解放
    
    console.log(`Detecting objects in image: ${imageWidth}x${imageHeight}`);
    
    // Workers AIの物体検出モデルを使用
    // 注: 現時点では汎用的な物体検出モデルしかないため、
    // ナンバープレート特化の検出精度は限定的
    
    const inputs = {
      image: Array.from(new Uint8Array(imageData)),
    };

    // @cf/facebook/detr-resnet-50 モデルを使用（物体検出）
    // 本番環境では、より特化したモデルまたは専用サービスの使用を推奨
    const response = await env.AI.run('@cf/facebook/detr-resnet-50' as any, inputs) as any;
    
    console.log('AI detection result:', JSON.stringify(response).substring(0, 500));
    
    // 検出結果から関連するオブジェクトをフィルタリング
    // （例: "license plate"、"car"、"vehicle" など）
    const detectedBoxes: Array<{ x: number; y: number; width: number; height: number }> = [];
    
    if (response && Array.isArray(response)) {
      const imageArea = imageWidth * imageHeight;
      
      for (const detection of response) {
        // 信頼度が高く、「car」ラベルのみを対象
        if (detection.score > 0.8 && (detection.label === 'car' || detection.label === 'truck')) {
          const box = detection.box || detection.bbox;
          if (box) {
            // detr-resnet-50は正規化された座標（0-1）を返すので、実際のピクセル座標に変換
            const xmin = box.xmin || box.x || 0;
            const ymin = box.ymin || box.y || 0;
            const xmax = box.xmax || (xmin + (box.width || 0));
            const ymax = box.ymax || (ymin + (box.height || 0));
            
            // 正規化されているか確認（値が0-1の範囲）
            const isNormalized = xmin <= 1 && ymin <= 1 && xmax <= 1 && ymax <= 1;
            
            let carBox;
            if (isNormalized) {
              // 正規化座標を実際のピクセル座標に変換
              carBox = {
                x: Math.floor(xmin * imageWidth),
                y: Math.floor(ymin * imageHeight),
                width: Math.floor((xmax - xmin) * imageWidth),
                height: Math.floor((ymax - ymin) * imageHeight),
              };
            } else {
              // すでにピクセル座標
              carBox = {
                x: Math.floor(xmin),
                y: Math.floor(ymin),
                width: Math.floor(xmax - xmin),
                height: Math.floor(ymax - ymin),
              };
            }
            
            const boxArea = carBox.width * carBox.height;
            const areaRatio = boxArea / imageArea;
            
            console.log(`Detected ${detection.label} (score: ${detection.score.toFixed(3)}), area: ${areaRatio.toFixed(4)}`, carBox);
            
            // 車のサイズが妥当か確認（画像の5%〜70%程度）
            const isReasonableCarSize = areaRatio > 0.05 && areaRatio < 0.70;
            
            if (isReasonableCarSize) {
              // 車の下部中央にナンバープレートがあると推定
              // ナンバープレートは車の高さの下部10-25%、幅の中央20-80%に位置すると仮定
              // 余裕を持って大きめの領域をマスキング
              const plateWidth = Math.floor(carBox.width * 0.55);  // 車幅の55%（余裕を持たせる）
              const plateHeight = Math.floor(carBox.height * 0.18); // 車高の18%（上下に余裕）
              const plateX = carBox.x + Math.floor(carBox.width * 0.225); // 中央寄せ（少し左寄り）
              const plateY = carBox.y + carBox.height - Math.floor(plateHeight * 2.2); // 下部（少し上から）
              
              const licensePlateBox = {
                x: Math.max(0, plateX),
                y: Math.max(0, plateY),
                width: Math.min(plateWidth, imageWidth - plateX),
                height: Math.min(plateHeight, imageHeight - plateY),
              };
              
              console.log('  -> Estimated license plate position:', licensePlateBox);
              detectedBoxes.push(licensePlateBox);
            } else {
              console.log('  -> Skipped (unreasonable car size)');
            }
          }
        }
      }
    }
    
    console.log(`Total detected: ${detectedBoxes.length} objects`);
    return detectedBoxes;
  } catch (error) {
    console.error('AI detection error:', error);
    // エラー時は空の配列を返す（マスキングなし）
    return [];
  }
}

/**
 * 画像をアップロードし、自動的にナンバープレートをマスキング
 * @param env Cloudflare環境変数
 * @param imageData 元の画像データ
 * @param fileName ファイル名
 * @returns {original: 元画像URL, masked: マスキング済み画像URL, detectedCount: 検出数, detectedBoxes: 検出領域}
 */
export async function uploadAndMaskImage(
  env: { AI: Ai; CAR_IMAGES: R2Bucket },
  imageData: ArrayBuffer,
  fileName: string
): Promise<{
  originalUrl: string;
  maskedUrl: string;
  detectedCount: number;
  detectedBoxes: Array<{ x: number; y: number; width: number; height: number }>;
}> {
  const timestamp = Date.now();
  const randomStr = Math.random().toString(36).substring(2, 15);
  const fileExt = fileName.split('.').pop() || 'jpg';
  const baseFileName = `${timestamp}-${randomStr}`;
  
  // 1. 元画像を保存
  const originalKey = `uploads/original/${baseFileName}.${fileExt}`;
  await env.CAR_IMAGES.put(originalKey, imageData);
  
  // 2. AIでナンバープレートを検出
  const detectedBoxes = await detectLicensePlates(env, imageData);
  
  // 3. マスキング処理（検出された領域があれば）
  let maskedKey: string;
  if (detectedBoxes.length > 0) {
    const maskedData = await maskImageRegions(imageData, detectedBoxes);
    maskedKey = `uploads/masked/${baseFileName}.${fileExt}`;
    await env.CAR_IMAGES.put(maskedKey, maskedData);
  } else {
    // 検出されなければ元画像と同じものを使用
    maskedKey = originalKey;
  }
  
  return {
    originalUrl: `/images/${originalKey}`,
    maskedUrl: `/images/${maskedKey}`,
    detectedCount: detectedBoxes.length,
    detectedBoxes,
  };
}
