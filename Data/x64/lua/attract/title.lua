-- Title.lua
-- タイトル画面

-- 対応するlumenファイル
UseLumenFile = "lumen/000_default/attract/title"

-- 使うクラスを読み込む
require("attract.title_main")

-- 初期化処理
function Init()
	-- タイトルのメイン初期化
	TitleMain:Init()
end

-- 毎フレームの処理
function Proc()
	TitleMain:Update()
end


