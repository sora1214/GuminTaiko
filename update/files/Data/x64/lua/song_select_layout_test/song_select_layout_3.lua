-- 対応するlumenファイル
-- UseLumenFile = "lumen/menu/game_setting/game_setting_test"
UseLumenFile = "lumen/song_select_layout_test/song_select_layout_3"

-- 使うクラスを読み込む
require("song_select_layout_test.song_select_layout_3_main")

-- 初期化処理
function Init()
	-- ここで使うモジュールを初期化
	Main:Init()
end

-- 毎フレームの処理
function Proc()
	Main:Update()
end

