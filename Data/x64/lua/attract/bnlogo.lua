-- BNLogo.lua
-- BNロゴ画面

-- 対応するlumenファイル
UseLumenFile = "lumen/000_default/attract/bnlogo"

-- 使うクラスを読み込む
require("common.Sound")
require("common.State")
require("common.Banner")

-- 初期化処理
function Init()
	-- シーケンス
	BNLogoScene = State.New("BNAMLogo")

	-- ステートマシン構築
	BNLogoScene.func_["Begin"] = function()
		BNLogoScene.banner_ = Banner.New("banner_instance",true,false,GameMode.kEnso)

		BNLogoScene.banner_:LoadMovie()
		BNLogoScene:SetState("Loading")
	end

	BNLogoScene.func_["Loading"] = function()
		if (Lumen.IsLoadMovieFinish() == true) then
			BNLogoScene:SetState("Loading2")
		end
	end
	BNLogoScene.func_["Loading2"] = function()
		-- 1フレ待ってから
		if(BNLogoScene.count_ >= 1) then
			-- ムービークリップ取得
			BNLogoScene.main_mc_ = Lumen.GetMovieClip("bnlogo_instance_0",true)
			-- flaはこの時点で１フレーム目から再生を開始する
			BNLogoScene.main_mc_:GotoAndPlay(1)

			-- バナーの準備
			BNLogoScene.banner_:Setup()
			BNLogoScene.banner_:Start()

			-- C側に準備完了通知
			Common.LuaPrepareFinish()

			BNLogoScene:SetState("FadeInWait")
		end
	end

	BNLogoScene.func_["FadeInWait"] = function()
		if(FadeFlag == false) then
			-- ここからカードタッチ有効
			BanaPass.StartCardTouch()
			-- ここからＱＲタッチ有効
			QR.StartQRTouch()

			BNLogoScene:SetState("Main")
		end
	end

	BNLogoScene.func_["Main"] = function()
		-- メニューテスト以外
		if(IsFromMenuTest == false) then
			-- 再生終了待ち
			if(BNLogoScene.main_mc_:IsPlay() == false) then
				BNLogoScene:SetState("EndWait")
			end
		end
	end

	BNLogoScene.func_["EndWait"] = function()
		-- シーン終了
		Common.LuaFinish()
		BNLogoScene:SetState("End")
	end
	BNLogoScene.func_["End"] = function()
	end
end

-- 毎フレームの処理
function Proc()
	BNLogoScene:Update()
	BNLogoScene.banner_:Update()
end


