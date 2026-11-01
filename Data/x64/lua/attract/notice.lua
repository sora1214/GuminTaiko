-- Notice.lua
-- NOTICE画面

-- 対応するlumenファイル
UseLumenFile = "lumen/000_default/attract/notice"

-- 使うクラスを読み込む
require("common.SimpleScene")

-- 初期化処理
function Init()
	-- シーケンス
	NoticeScene = SimpleScene.New("Notice","notice_instance_0")
end

-- 毎フレームの処理
function Proc()
	NoticeScene:Update()
end


