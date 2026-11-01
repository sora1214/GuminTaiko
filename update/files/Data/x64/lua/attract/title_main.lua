-- 使うクラスを読み込む
require("common.Sound")
require("common.State")
require("common.Banner")

-- このクラス
TitleMain = {

	-- 変数
	state_ = State.New("TitleMain"),
	banner_ = Banner.New("banner_instance",true,false,GameMode.kEnso),
	nowtime_ = 0,
	totaltime_ = Common.FPS * 6.5,
	titlecalltime_ = Common.FPS * 1.5,

	-- 初期化関数
	Init = function(this)
		-- ステートマシンの組み立て
		this.state_.func_["Begin"] = function()
			-- 各種パーツ読み込み
			this.banner_:LoadMovie()
--			Lumen.LoadMovie("lumen/000_default/common/numberofstage","numberofstage_instance")

			this.state_:SetState("Loading")
		end
		this.state_.func_["Loading"] = function()
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
--				this.numberofstage_mc_ = Lumen.GetMovieClip("numberofstage_instance",true)

				-- テキスト設定
--				this.numberofstage_mc_:SetText("number_instance","text_oneplay","attract_one_play")
--				this.numberofstage_mc_:SetText("number_instance","text_numofstage","attract_numberofstage")

				-- バナーの準備
				this.banner_:Setup()
				this.banner_:Start()

				-- C側に準備完了通知
				Common.LuaPrepareFinish()

				this.state_:SetState("FadeInWait")
			end
		end
		this.state_.func_["FadeInWait"] = function()
			if(FadeFlag == false) then
				-- 曲の再生
				TSound:PlaySlot("bgm_common_v12a","title_v12a",0)

				-- ここからカードタッチ有効
				local card_status = BanaPass.GetCardTouchStatus()
				if((card_status == GameConnectStatus.kSuccess) or (card_status == GameConnectStatus.kError)) then
				else
					BanaPass.StartCardTouch()
				end
				-- ここからＱＲタッチ有効
				local qr_status = QR.GetQRTouchStatus()
				if((qr_status == GameConnectStatus.kSuccess) or (qr_status == GameConnectStatus.kError)) then
				else
					QR.StartQRTouch()
				end

				this.nowtime_ = 0
				this.state_:SetState("Main")
			end
		end
		this.state_.func_["Main"] = function()
			this.nowtime_ = this.nowtime_ + 1

			-- タイトルコール
			if(this.nowtime_ == this.titlecalltime_) then
				TSound:PlaySlot("voice_common_v12a","title",1)
			end

			-- 時間管理
			if(this.nowtime_ > this.totaltime_) then
				this.state_:SetState("EndWait")
			end
		end

		this.state_.func_["EndWait"] = function()
			-- シーン終了
			Common.LuaFinish()
			TSound:StopSlot(1)
			this.state_:SetState("End")
		end
		this.state_.func_["End"] = function()
		end
	end,

	-- 毎フレーム処理関数
	Update = function(this)
		-- ステートマシン実行
		this.state_:Update()
		this.banner_:Update()
	end
}
