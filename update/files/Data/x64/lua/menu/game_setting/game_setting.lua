-- 対応するlumenファイル
-- UseLumenFile = "lumen/menu/game_setting/game_setting_test"
UseLumenFile = "lumen/animate/menu/game_setting/game_setting"

-- 使うクラスを読み込む
require("menu.game_setting.game_setting_main")

-- 初期化処理
function Init()
	-- ここで使うモジュールを初期化
	Main:Init()
end

-- 毎フレームの処理
function Proc()
	Main:Update()
end

-- 個別の処理
-- パーツ設定
function SetupTopMenuParts()
	-- タイトル設定
	-- 入力ガイド設定
end
