-- AI遊び方説明画面.グローバル変数Lua
-- Masayuki_Teraoka@al.bandainamco.jp

-- 対応するlumenファイル
UseLumenFile = "lumen/000_default/enso_ai/tutorial/tutorial"

-- --=== 定数
play_data_ = 0 							-- 各ユーザーの過去プレイデータ記録(V11までのプレイデータなど)

-- --=== グローバル変数
-- -- 結果
nextMode = -1							-- 遷移先

is_joinLeft = false
is_joinRight = false

-- プレイヤーの参加情報を得る
SetPlayerJoin = function(isJoinLeft, isJoinRight)
	
	is_joinLeft = isJoinLeft
	is_joinRight = isJoinRight
	
	if (isJoinLeft == true) then
		is_joinPlayer[1]	= true	-- 1p側で参加
	else
		is_joinPlayer[2]	= true	-- 2p側で参加
	end
end

SetPlayerJoin(is_joinPlayer[1], is_joinPlayer[2])

-- 使うクラスを読み込む
require("ai_tutorial.ai_tutorial_all")

-- 初期化処理
function Init()
	-- ここで使うモジュールを初期化
	AITutorialAllMain:Init()
end

-- 毎フレームの処理
function Proc()
	AITutorialAllMain:Update()
end

