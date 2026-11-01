#pragma once
#include "raylib.h"

// どんちゃん（side=0）／かっちゃん（side=1）を 2D で描く（3D モデルの代わり）
// costume: 0 いつもの / 1 クール / 2 キュート / 3 ジョーク。gray はクレジット待ちの状態
void DrawDonSprite(Vector2 center, float radius, int side, int costume, bool gray, float alpha = 1.0f);
