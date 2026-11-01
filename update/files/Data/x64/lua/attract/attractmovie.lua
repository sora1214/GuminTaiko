-- attractmovie.lua
-- アトラクトムービー画面

-- 対応するlumenファイル
UseLumenFile = "lumen/000_default/attract/attractmovie"

-- 使うクラスを読み込む
require("common.State")
require("common.Banner")

-- 初期化処理
function Init()
	-- シーケンス
	AttractMovieScene = State.New("AttractMovie")

	-- ステートマシン構築
	AttractMovieScene.func_["Begin"] = function()
		AttractMovieScene.banner_ = Banner.New("banner_instance",true,true,GameMode.kEnso)
		AttractMovieScene.banner_:LoadMovie()

		AttractMovieScene:SetState("Loading")
	end

	AttractMovieScene.func_["Loading"] = function()
		if (Lumen.IsLoadMovieFinish() == true) then
			-- バナーの準備
			AttractMovieScene.banner_:Setup()
			AttractMovieScene.banner_:Start()
			AttractMovieScene.bannerDisp_ = false
			AttractMovieScene.banner_:SetVisible(AttractMovieScene.bannerDisp_)

			-- C側に準備完了通知
			Common.LuaPrepareFinish()

			AttractMovieScene:SetState("Main")
		end
	end
	AttractMovieScene.func_["Main"] = function()
		if(AttractMovieScene.bannerDisp_ ~= IsBannerAvailable) then
			AttractMovieScene.bannerDisp_ = IsBannerAvailable
			AttractMovieScene.banner_:SetVisible(AttractMovieScene.bannerDisp_)
		end
	end
end

-- 毎フレームの処理
function Proc()
	AttractMovieScene:Update()
	AttractMovieScene.banner_:Update()
end


