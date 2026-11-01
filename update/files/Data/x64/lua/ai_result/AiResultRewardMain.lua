-- AiResultRewardMain.lua
-- AIバトルリザルト画面:ごほうび部分
AiResultRewardMain = {}

-- 使うクラスを読み込む
require("common.Sound")
require("common.State")
require("common.NamePlate")
require("ai_result.AiResultScoreCounter")
require("ai_result.AiResultWinCounter")
require("ai_result.AiResultBg")
require("ai_result.AiResultReward")
require("ai_result.AiResultRewardToken")
require("ai_result.AiResultEventTokenBg")

-- このクラス
function AiResultRewardMain.New()
	return
	{
		-- 定数
		kWaitEffectEndTime_ = 200,	-- 全演出が終了してから入力を受け付けが再開するまでの待機時間

		-- 変数
		state_				= State.New("AiResultRewardMain"),

		tokenBase_			= AiResultRewardToken.New("AiResultRewardToken"),
		tokenBaseMc_,
		rewardBase_			= AiResultReward.New("AiResultReward"),
		rewardBaseMc_,
		eventTokenBg_		= AiResultEventTokenBg.New("event_token_bg_L"),
		controlGuideLMc_,
		eventTokenBgMc_,
		sectionMainMc_,

		namePlate_,					-- ネームプレート

		timer_				= 0,	-- 更新用タイマー

		-- ムービークリップ
		mc_,							-- メインmc
		mcToken_,						-- 通常トークン
		--mcReward_,					-- ごほうび
		
		-- フラグ
		isStandardEnd_		= false,	-- 通常ごほうび付与完了
		isTokenEnd_			= false,	-- どんメダルとイベントトークン付与完了
		isEnd_				= false,

		----------------------------------------
		-- state処理
		Init = function(this)
			-- 全体シーケンス
			this.state_.func_["Begin"] = function()
				-- 開始
				Debug.PrintString("[AiResultRewardMain] Begin")
				this.state_:SetState("Loading")
			end

			this.state_.func_["Loading"] = function()
				-- 読み込み待ち
				if (Lumen.IsLoadMovieFinish() == true) then
					Debug.PrintString("[AiResultRewardMain] Loading Finish")
					this.timer_ = 0
					this.state_:SetState("StandardWait")
					return
				end
			end

			this.state_.func_["StandardWait"] = function()
				if(this.timer_ > 100) then
					Debug.PrintString("[AiResultRewardMain] StandardWait Finish")
					this.timer_ = 0

					-- メイン開始
					this.state_:SetState("StandardReward")
					this.rewardBase_:UpdateRewardPanel(-1, true)
					return
				end
			end

			this.state_.func_["TokenWait"] = function()
				if(this.timer_ > 100) then
					Debug.PrintString("[AiResultRewardMain] TokenWait Finish")
					this.timer_ = 0

					-- メイン開始
					this.state_:SetState("NormalToken")
					this.tokenBase_:StartUpdateNormalToken()
					return
				end
			end

			this.state_.func_["StandardReward"] = function()
				-- ごほうびパネルが終了したか否かを常に問い合わせ、完了し次第次のシーケンスへ遷移
				if(this.rewardBase_:GetIsRewardPanelEnd() == true) then
					this.timer_ = 0
					--this.tokenBase_:StartUpdateNormalToken()
					Debug.PrintString("[AiResultRewardMain] StandardReward Finish")
					--this.state_:SetState("NormalToken")
					this.state_:SetState("StandardEnd")
					return
				end
				this.rewardBase_:Update()
			end

			this.state_.func_["NormalToken"] = function()
				-- 通常トークン演出が終了したか否かを常に問い合わせ、完了し次第次のシーケンスへ遷移
				if(this.tokenBase_:GetIsNormalTokenEnd() == true) then
					this.timer_ = 0
					this.tokenBase_:StartUpdateEventToken()

					Debug.PrintString("[AiResultRewardMain] NormalToken Finish")
					this.state_:SetState("EventToken")
					return
				end
				this.rewardBase_:Update()
				this.tokenBase_:Update()
			end

			this.state_.func_["EventToken"] = function()
				-- イベントトークン演出が終了したか否かを常に問い合わせ、完了し次第次のシーケンスへ遷移
				if(this.tokenBase_:GetIsEventTokenEnd() == true) then
					this.timer_ = 0
					this.state_:SetState("TokenEnd")
					return
				end
				this.rewardBase_:Update()
				this.tokenBase_:Update()
			end

			this.state_.func_["mainIn"] = function()
				if(this.timer_ >= this.kWaitEffectEndTime_)then
--				if(InputDon() == true)then
					Debug.PrintString("[AiResultRewardMain] mainIn Finish")
					this.state_:SetState("End")
				end
			end

			this.state_.func_["StandardEnd"] = function()
				if(g_addNormalToken > 0 or g_addEventToken > 0)then
					if(this.timer_ >= this.kWaitEffectEndTime_)then
						Debug.PrintString("[AiResultRewardMain] StandardEnd")
						this.timer_ = 0
						this.isStandardEnd_ = true
					end
				else
					Debug.PrintString("[AiResultRewardMain] StandardEnd")
					this.timer_ = 0
					this.isStandardEnd_ = true
				end
			end

			this.state_.func_["TokenEnd"] = function()
				if(this.timer_ >= this.kWaitEffectEndTime_)then
					Debug.PrintString("[AiResultRewardMain] TokenEnd")
					this.timer_ = 0
					this.isTokenEnd_ = true
				end
			end

			this.state_.func_["End"] = function()
				Debug.PrintString("[AiResultRewardMain] End")
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
		SetUp = function(this, tokenMc, eventTokenBgMc, namePlate, guide)
			Debug.PrintString("[AiResultRewardMain] SetUp")
			-- mcの設定
			this.mcToken_	= tokenMc
			--this.mcReward_	= rewardMc
			this.namePlate_	= namePlate

			this.controlGuideLMc_	= guide
			this.eventTokenBgMc_	= eventTokenBgMc

			-- 値の設定

			-- 仮の設定
			this:SetToken()
		end,

		-- LoadMovie
		LoadMovie = function(this)
			-- 読み込み
			Debug.PrintString("[AiResultRewardMain] LoadMovie")
			Lumen.LoadMovie("lumen/000_default/result/result_reward","dummy_reward")						-- ごほうび
			Lumen.LoadMovie("lumen/000_default/result/result_reward","dummy_reward_section")				-- ごほうび

			Lumen.LoadMovie("lumen/000_default/result/control_guide","control_guide_L")						-- 操作ガイド

			this.eventTokenBg_:LoadMovie()
		end,

		SetStandardReward = function(this)
			-- 通常ごほうび付与の開始準備
			Debug.PrintString("[AiResultRewardMain] SetStandardReward")
			this.state_:SetState("StandardWait")

		end,

		SetTokenReward = function(this)
			-- トークン付与の開始準備
			Debug.PrintString("[AiResultRewardMain] SetTokenReward")
			this.state_:SetState("TokenWait")

		end,

		----------------------------------------
		-- その他

		-- メダル獲得
		SetToken = function(this)
			Debug.PrintString("[AiResultRewardMain] SetToken")
			--this.mcToken_.main:GotoAndStop("use_left")
			--this.mcToken_.main.token_base_L:GotoAndPlay("init")
			--this.mcToken_.main.token_base_L.normal_token_mc:GotoAndStop("init")

			-- 通常ごほうびの獲得関連
			this.mcToken_.main:GotoAndStop("use_left")
			this.tokenBaseMc_ = this.mcToken_.main:GetChildMc("token_base_L",true)				-- 左側の token_base を tokenBase1p_ として初期化
			this.tokenBase_:Init(this.tokenBaseMc_, 1, this.rewardBase_, this.eventTokenBg_)
			this.rewardBaseMc_ = this.mcToken_.main:GetChildMc("reward_base_L",true)			-- 左側のごほうびウィンドウMCを　rewardBase1pMc_　として初期化
			this.rewardBase_:Init(this.rewardBaseMc_, 1, this.namePlate_, this.eventTokenBg_)

			-- this.controlGuideLMc_ = this.m_MainMc:GetChildMc("control_guide_L",true)
			this.rewardBase_:InitControlGuide(this.controlGuideLMc_)

			this.eventTokenBg_:Setup(1, this.eventTokenBgMc_)
			Debug.PrintString("[AiResultRewardMain] SetToken Finish")
		end,

		DebugSetStart = function(this)
			--Debug.PrintString("[AiResultRewardMain] DebugSetStart")
			--this.mcReward_.main:GotoAndStop("use_right")
			----this.mcReward_.main:GotoAndStop("use_left")
			--this.mcReward_.main.reward_base_R.reward_panel:GotoAndPlay("start")
			--this.mcReward_.main.token_base_R:GotoAndPlay("start")
			--this.mcToken_.main:GotoAndStop("use_left")
			--this.mcToken_.main.token_base_L:GotoAndPlay("start")
		end,

	}
end
