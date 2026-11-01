-- AiResultWinCountMain.lua
-- AIバトルリザルト画面:勝利数ごほうびの部分
AiResultWinCountMain = {}

-- 使うクラスを読み込む
require("common.Sound")
require("common.State")
require("common.NamePlate")
require("ai_result.AiResultScoreCounter")
require("ai_result.AiResultWinCounter")
require("ai_result.AiResultBg")
require("ai_result.AiResultWinCountReward")
--require("ai_result.AiResultWinCountToken")
require("ai_result.AiResultEventTokenBg")

-- このクラス
function AiResultWinCountMain.New()
	return
	{
		-- 定数
		kWaitEffectEndTime_ = 200,	-- 全演出が終了してから入力を受け付けが再開するまでの待機時間

		-- 変数
		state_				= State.New("AiResultWinCountMain"),

		--tokenBase_			= AiResultWinCountToken.New("AiResultWinCountToken"),
		tokenBaseMc_,
		rewardBase_			= AiResultWinCountReward.New("AiResultWinCountReward"),
		rewardBaseMc_,
		-- eventTokenBg_		= AiResultEventTokenBg.New("event_token_bg_R"),
		controlGuideRMc_,
		controlGuideLMc_,
		-- eventTokenBgMc_,
		nextRewardNum_,			-- 次の勝利数カウンター
		sectionMain_,			-- 区間メイン

		namePlate_,					-- ネームプレート
		timer_				= 0,	-- 更新用タイマー

		-- ムービークリップ
		mc_,							-- メインmc
		mcToken_,						-- 通常トークン
		mcReward_,						-- ごほうび
		
		-- フラグ
		isEnd_				= false,

		----------------------------------------
		-- state処理
		Init = function(this)
			-- 全体シーケンス
			this.state_.func_["Begin"] = function()
				-- 開始
				Debug.PrintString("[AiResultWinCountMain] Begin")
				this.state_:SetState("Loading")
			end

			this.state_.func_["Loading"] = function()
				-- 読み込み待ち
				if (Lumen.IsLoadMovieFinish() == true) then
					Debug.PrintString("[AiResultWinCountMain] Loading Finish")
					this.timer_ = 0
					this.state_:SetState("Wait")
					return
				end
			end

			this.state_.func_["Wait"] = function()
				if(this.timer_ > 100) then
					Debug.PrintString("[AiResultWinCountMain] Wait Finish")
					this.timer_ = 0

					-- メイン開始
					this.state_:SetState("WinCount")
					this.rewardBase_:UpdateRewardPanel(-1, true)
					return
				end
			end

			this.state_.func_["WinCount"] = function()
				-- ごほうびパネルが終了したか否かを常に問い合わせ、完了し次第次のシーケンスへ遷移
				if(this.rewardBase_:GetIsRewardPanelEnd() == true) then
					Debug.PrintString("[AiResultWinCountMain] WinCount Finish")
					this.timer_ = 0

					-- メイン開始
					this.state_:SetState("Reward")
					return
				end
				this.rewardBase_:Update()
			end

			this.state_.func_["Reward"] = function()
				if(this.timer_ >= this.kWaitEffectEndTime_)then
				--if(InputDon() == true)then
					Debug.PrintString("[AiResultWinCountMain] Reward Finish")
					this.state_:SetState("End")
				end
			end

			this.state_.func_["End"] = function()
				Debug.PrintString("[AiResultWinCountMain] End")
				this.isEnd_ = true
			end
		end,

		-- 更新
		Update = function(this)
			-- ステート処理
			this.state_:Update()
			this.timer_ = this.timer_ + 1	--　タイマ更新
		end,

		-- 初期値の設定
		SetUp = function(this, tokenMc, rewardMc, eventTokenBgMc, namePlate, guideR, guideL, sectionMain)
			Debug.PrintString("[AiResultWinCountMain] SetUp")
			-- mcの設定
			this.mcToken_	= tokenMc
			this.mcReward_	= rewardMc
			this.namePlate_	= namePlate

			this.controlGuideRMc_	= guideR
			this.controlGuideLMc_	= guideL
			-- this.eventTokenBgMc_	= eventTokenBgMc
			this.sectionMain_		= sectionMain

			-- 値の設定

			-- 仮の設定
			this:SetWinCount()
			--this:DebugSetStart()
		end,

		-- LoadMovie
		LoadMovie = function(this)
			-- 読み込み
			Debug.PrintString("[AiResultWinCountMain] LoadMovie")
			Lumen.LoadMovie("lumen/000_default/result/result_reward","dummy_reward_section")				-- ごほうび
			Lumen.LoadMovie("lumen/000_default/result/control_guide","control_guide_R")						-- 操作ガイド

			-- this.eventTokenBg_:LoadMovie()
		end,

		----------------------------------------
		-- その他

		-- 勝利数カウント
		SetWinCounter = function(this, winCounter)
			Debug.PrintString("[AiResultWinCountMain] SetWinCounter")
			this.nextRewardNum_	= winCounter
		end,

		-- 勝利数の設定
		SetWinCount = function(this)
			Debug.PrintString("[AiResultWinCountMain] SetWinCount")
			this.mcReward_.main:GotoAndStop("use_left")
			--this.mcReward_.main.reward_base_R.reward_panel:GotoAndPlay("start")
			--this.mcReward_.main.token_base_R:GotoAndPlay("start")

			-- 通常ごほうびの獲得関連
			this.tokenBaseMc_ = this.mcToken_.main:GetChildMc("token_base_L",true)				-- 左側の token_base を tokenBase1p_ として初期化
			this.rewardBaseMc_ = this.mcReward_:GetChildMc("main",true)							-- 左側のごほうびウィンドウMCを　rewardBase1pMc_　として初期化
			this.rewardBase_:Init(this.rewardBaseMc_, this.tokenBaseMc_, 1, this.namePlate_, this.nextRewardNum_, this.sectionMain_)

			-- this.controlGuideLMc_ = this.m_MainMc:GetChildMc("control_guide_L",true)
			this.rewardBase_:InitControlGuide(this.controlGuideRMc_, this.controlGuideLMc_)

			-- this.eventTokenBg_:Setup(1, this.eventTokenBgMc_)
			Debug.PrintString("[AiResultRewardMain] SetWinCount Finish")
		end,

		DebugSetStart = function(this)
			Debug.PrintString("[AiResultWinCountMain] DebugSetStart")
			--this.mcReward_.main:GotoAndStop("use_right")
			this.mcReward_.main:GotoAndStop("use_left")
			this.mcReward_.main.reward_base_R.reward_panel:GotoAndPlay("start")
			this.mcReward_.main.token_base_R:GotoAndPlay("start")
			this.mcToken_.main:GotoAndStop("use_left")
			this.mcToken_.main.token_base_L:GotoAndPlay("start")
		end,

	}
end
