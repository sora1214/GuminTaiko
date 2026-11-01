-- 対応するlumenファイル
UseLumenFile = "lumen/000_default/entry/entry"

-- 使うクラスを読み込む
require("entry.entry_main")

-- 初期化処理
function Init()
	-- ここで使うモジュールを初期化
	EntryMain:Init()
end

-- 毎フレームの処理
function Proc()
	EntryMain:Update()
end

