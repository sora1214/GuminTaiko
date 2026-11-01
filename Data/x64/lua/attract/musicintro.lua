-- MusicIntro.lua
-- 曲紹介画面

-- 対応するlumenファイル
UseLumenFile = "lumen/000_default/attract/musicintro"

-- 使うクラスを読み込む
require("attract.musicintro_main")

-- 初期化処理
function Init()
	-- メイン初期化
	MusicIntroMain:Init()
end

-- 毎フレームの処理
function Proc()
	MusicIntroMain:Update()
end


