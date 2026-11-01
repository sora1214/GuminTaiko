-- AiResultSectionMain.lua
-- AIバトルリザルト画面:区間部分
AiResultSectionMain = {}

-- 使うクラスを読み込む
require("common.Sound")
require("common.State")
require("common.NamePlate")
require("ai_result.AiResultScoreCounter")
require("ai_result.AiResultWinCounter")
require("ai_result.AiResultBg")

-- このクラス

function AiResultSectionMain.New()
	return
	{
		-- 定数
		--kMaxGage_			= 50,	-- 魂ゲージの最大値
		--kGageSpeed_			= 7,	-- 魂ゲージが１メモリ進むのに必要な時間
		--kWaitEffectEndTime_ = 500,	-- 全演出が終了してから入力を受け付けが再開するまでの待機時間
		kWaitSectionIconEndTime_	= 60,		-- 区間勝敗が終了してから次の演出に移るまでの待機時間
		kWaitResultIconEndTime_		= 60,		-- 勝敗アイコンが終了してから次の演出に移るまでの待機時間
		kWaitEffectEndTime_			= 120*30,	-- カツ入力で詳細が見れる状態になってからの待機時間(120fps x 30秒)
		kWinCountMax_				= 999999,	-- 勝利数の最大値

		kResult = 1,		-- 区間勝敗
		kDetail = 2,		-- 区間詳細

		kWinCountState = {
			-- 合計勝利数の表示演出
			Fadein_			= 0,
			TotalWin_		= 1,
			NextReward_		= 2,
			Flash_			= 3,
		},

		-- 変数
		state_				= State.New("AiResultSectionMain"),

		scoreNum_			= {},
		scoreNumBack_		= {},
		goodNum_			= {},
		okNum_				= {},
		badNum_				= {},
		dramrollNum_		= {},

		bestScore_			= {},
		bestGoodNum_		= {},
		bestOkNum_			= {},
		bestBadNum_			= {},
		bestDramrollNum_	= {},

		totalWinNum_,
		NextRewardNum_,

		timer_					= 0,	-- 更新用タイマー
		simpleIndex_			= 0,	-- 区間勝敗の更新用添え字
		nowSectionIndex_		= 0,	-- 現在の表示項目(0:勝敗, 1:詳細)
		nextRewardIndex_		= 0,	-- 次のごほうびまでの勝利数

		winCountState_			= 0,

		aiResultRewardMain_,			-- ごほうび表示クラス
		aiResultWinCountMain_,			-- 勝利数ごほうびクラス

		-- ムービークリップ
		mc_,							-- メインmc
		mcSectionDeteil_	= {},		-- 区間詳細
		mcGuide_,						-- 操作ガイド
		--controlGuideLmc_,				-- 左側操作ガイド
		
		-- フラグ
		isEnd_				= false,
		isEndSimple_		= false,		-- 区間勝敗の演出完了
		isEndResultIcon_	= false,		-- 勝敗アイコンの演出完了
		isEndWinCount_		= false,		-- 勝利数の演出完了
		isEffectSkip_		= false,		-- true:スキップ使用可能, false:スキップ使用不可
		isGuideEnd_			= false,		-- 操作ガイド表示完了

		isNewRecord_		= {},			-- ハイスコア演出を出す
		-- isWinCountReward_	= false,	-- 次のごほうびまでの勝利数を出す
		--isEndScore_		= false,		-- スコア更新終了

		----------------------------------------
		-- state処理
		Init = function(this)
			-- 全体シーケンス
			this.state_.func_["Begin"] = function()
				-- 開始
				Debug.PrintString("[AiResultSectionMain] Begin")
				this.state_:SetState("Loading")
			end

			this.state_.func_["Loading"] = function()
				-- 読み込み待ち

				if (Lumen.IsLoadMovieFinish() == true) then
					Debug.PrintString("[AiResultSectionMain] Loading Finish")
					this.timer_ = 0
					this.state_:SetState("Wait")
					return
				end
				Debug.PrintString("[AiResultSectionMain] Loading Wait...")
			end

			this.state_.func_["Wait"] = function()
				if(this.timer_ > 100) then
					Debug.PrintString("[AiResultSectionMain] Wait Finish")
					this.timer_ = 0

					-- メイン開始
					this.state_:SetState("FadeIn")
					this.mc_:GotoAndPlay("in")
					return
				end
				Debug.PrintString("[AiResultSectionMain] Wait...")
			end

			this.state_.func_["FadeIn"] = function()
				-- フェードイン
				if(this.timer_ > 55) then
					Debug.PrintString("[AiResultSectionMain] Wait Finish")
					this.timer_ = 0

					-- メイン開始
					this.state_:SetState("Simple")
					this.isEffectSkip_ = true
					return
				end
			end

			this.state_.func_["Simple"] = function()
				-- 区間勝敗
				if(this.isEndSimple_ == false)then
					this:UpdateSimple()
				end

				-- if(this.isEndSimple_ == true)then
				if(this.isEndSimple_ == true and this.timer_ > this.kWaitSectionIconEndTime_)then
					Debug.PrintString("[AiResultSectionMain] Simple Finish")
					this.timer_ = 0
					this.state_:SetState("ResultIcon")
					this:StartResultIcon()
				end
			end

			this.state_.func_["ResultIcon"] = function()
				-- 勝敗アイコン
				if(this.isEndResultIcon_ == false)then
					this:UpdateResultIcon()
					if(this.isEndResultIcon_ == true)then
						this.timer_ = 0
					end
				end

				if(this.timer_ > this.kWaitResultIconEndTime_)then
					--終了
					Debug.PrintString("[AiResultSectionMain] ResultIcon Finish")
					this.timer_ = 0
					this.state_:SetState("DonAiMotion")
					this:StartDonAIMotion()	-- AIどんのモーション
				end
			end

			this.state_.func_["DonAiMotion"] = function()

				if(this.timer_ == 300)then
					this:StayDonMotion()	-- どんモーションの再生を止める
				end

				if(this.timer_ >= 360)then
					if(g_winCountDisplay_ == kWinCountNone)then
						-- 合計勝利数を表示しない
						this.timer_ = 0
						this.state_:SetState("mainWait")
						this.isEffectSkip_ = false
						this:StartGuide()		-- 操作ガイドの開始
					else
						-- 合計勝利数を表示する
						this.timer_ = 0
						this.state_:SetState("WinCount")
						this:StartTotalWinCount()		-- 合計勝利数の開始
					end
				end
			end

			this.state_.func_["WinCount"] = function()
				-- 勝利数カウント
				if(this.isEndWinCount_ == false)then
					this:UpdateTotalWinCount()
				end
				
				if(this.isEndWinCount_ == true)then
					--終了
					Debug.PrintString("[AiResultSectionMain] WinCount Finish")
					this.timer_ = 0
					this.isEffectSkip_ = false
					if(g_isCardUser_ == true)then
						---- カードユーザーの場合
						this.timer_ = 0
						this.state_:SetState("RewardWait")
						--this:StartGuide()		-- 操作ガイドの開始
					else
						-- カードユーザーではない場合
						Debug.PrintString("[AiResultSectionMain] Reward Finish")
						this.timer_ = 0
						this.state_:SetState("mainWait")
						this:StartGuide()		-- 操作ガイドの開始
					end
				end
			end

			this.state_.func_["EffectSkip"] = function()
				-- スキップ演出
				this:SkipSimple()		-- 区間勝敗
				this:SkipResultIcon()	-- 勝敗
				this:StartDonAIMotion()	-- AIどんのモーション
				
				if(g_winCountDisplay_ == kWinCountReward)then
					this:SkipTotalWinCount()
				elseif(g_winCountDisplay_ == kWinCountReward)then
					this:SkipTotalWinCount()
				end

				this.timer_ = 0
				this.isEffectSkip_ = false
				this.state_:SetState("EffectSkipWait")
			end

			this.state_.func_["EffectSkipWait"] = function()
				if(this.timer_ >= 200)then
					this.timer_ = 0
					Debug.PrintString("[AiResultSectionMain] EffectSkipWait Finish")
					if(g_isCardUser_ == true)then
						--end
						this.timer_ = 0
						this.state_:SetState("RewardWait")
						--this:StartGuide()		-- 操作ガイドの開始
					else
						-- カードユーザーではない場合
						this.timer_ = 0
						this.state_:SetState("mainWait")
						this:StartGuide()		-- 操作ガイドの開始
					end
				end
			end

			this.state_.func_["RewardWait"] = function()
				-- ごほうび前の詳細確認画面

				Debug.PrintString("[AiResultSectionMain] RewardWait Finish")
				if(g_isCardUser_ == true)then
					-- 操作ガイド
					--this:FadeOutGuide()

					-- カードユーザーの場合
					if(g_aiGetRewardNum > 0)then
						-- 勝利数ごほうびがある場合
						this.state_:SetState("WinCountReward")

					elseif(g_getRewardNum > 0 or g_addNormalToken > 0 or g_addEventToken > 0)then
						-- 獲得したごほうび or トークンがある場合
						this.state_:SetState("Reward")
						this.aiResultRewardMain_:SetStandardReward()	-- ごほうび付与の開始
						this:EndTotalWinCount()							-- 勝利数のウィンドウ終了
					else
						-- ごほうびが無い場合
						this.timer_ = 0
						this.state_:SetState("mainWait")
						this:StartGuide()		-- 操作ガイドの開始
						this:EndTotalWinCount()							-- 勝利数のウィンドウ終了
					end
				else
					if(g_isLastSong_ == false)then
						-- サウンド再生
						--TSound:Play("se_common_v12a","don_c")
					end
					this.state_:SetState("End")
				end
			end

			this.state_.func_["WinCountReward"] = function()
				-- 勝利数ごほうび演出
				if(this.aiResultWinCountMain_.isEnd_ == true) then
					--終了
					Debug.PrintString("[AiResultSectionMain] Reward Finish")
					this.timer_ = 0

					if(g_getRewardNum > 0 or g_addNormalToken > 0 or g_addEventToken > 0)then
						-- 全曲演奏 and クリアごほうび獲得時
						this.state_:SetState("Reward")
						this.aiResultRewardMain_:SetStandardReward()	-- ごほうび付与の開始
					else
						-- そうでない場合、区間詳細切り替え画面へ
						this.timer_ = 0
						this.state_:SetState("mainWait")
						this:StartGuide()		-- 操作ガイドの開始
					end
				end
				this.aiResultWinCountMain_:Update()
			end

			this.state_.func_["Reward"] = function()
				-- 通常ごほうび付与
				if(this.aiResultRewardMain_.isStandardEnd_ == true) then
					-- 終了
					Debug.PrintString("[AiResultSongMain] Reward Finish")
					this.timer_ = 0

					if(g_addNormalToken > 0 or g_addEventToken > 0)then
						-- 付与するトークンがある場合
						this.state_:SetState("TokenReward")
						this.aiResultRewardMain_:SetTokenReward()		-- トークン付与の開始
					else
						-- ない場合、区間詳細切り替え画面へ
						this.timer_ = 0
						this.state_:SetState("mainWait")
						this:StartGuide()		-- 操作ガイドの開始
					end
				end
				this.aiResultRewardMain_:Update()
			end

			this.state_.func_["TokenReward"] = function()
				-- トークン付与
				if(this.aiResultRewardMain_.isTokenEnd_ == true) then
					--終了
					Debug.PrintString("[AiResultSectionMain] Reward Finish")
					this.timer_ = 0
					this.state_:SetState("mainWait")
				end
				this.aiResultRewardMain_:Update()
			end

			this.state_.func_["mainWait"] = function()
				if(this.timer_ > 100)then
					this.timer_ = 0
					this.state_:SetState("mainIn")
					this:StartGuide()		-- 操作ガイドの開始
				end
			end

			this.state_.func_["mainIn"] = function()
				if(this.mc_.dummy_guide.main:IsInCurrentLabelMc("","stop"))then
					if(InputKatsu_Right() == true or InputKatsu_Left() == true)then
						-- 勝敗と詳細の切り替え
						this:SwitchSection()
					end

					if(InputDon() == true or this.timer_ > this.kWaitEffectEndTime_)then
						Debug.PrintString("[AiResultSectionMain] mainIn Finish")
						-- サウンド再生
						TSound:Play("se_common_v12a","don_c")
						this.state_:SetState("End")
					end
				else
					-- 操作ガイドのUpdate
					this:UpdateGuide()
				end
			end

			this.state_.func_["End"] = function()
				Debug.PrintString("[AiResultSectionMain] End")
				this.isEnd_ = true
			end
		end,

		-- 更新
		Update = function(this)
			-- ステート処理
			this.state_:Update()
			this.timer_ = this.timer_ + 1	--　タイマ更新

			--if(this.isEffectSkip_ == true and InputDon() == true)then
			--	-- スキップ
			--	this.timer_ = 0
			--	this.isEffectSkip_ = false
			--	this.state_:SetState("EffectSkip")
			--
			--	-- サウンド
			--	TSound:Play("se_common_v12a","don_c")
			--end
		end,

		-- 初期値の設定
		SetUp = function(this, mc, rewardMain, winCountMain, controlGuideL)
			Debug.PrintString("[AiResultSectionMain] SetUp")
			-- mcの設定
			this.mc_ = mc
			this.mc_:GotoAndStop("in")
			this.aiResultWinCountMain_	= winCountMain
			this.aiResultRewardMain_	= rewardMain
			-- 左側操作ガイド
			this.mcGuide_ = controlGuideL:GetChildMc("main",true)

			-- 値の設定

			-- 仮の設定
			this:InitDonAI()
			this:SetSimple()
			this:SetResultIcon()
			this:SetSectionDeteil()
			this:SetGuide()
			this:SetTotalWinCount()
		end,

		-- LoadMovie
		LoadMovie = function(this)
			-- 読み込み
			-- Lumen.LoadMovie("lumen/000_default/enso_ai/result/result_ai_control_guide","dummy_guide")		-- 操作ガイド
			Lumen.LoadMovie("lumen/000_default/result/control_guide","dummy_guide")							-- 操作ガイド
			Lumen.LoadMovie("lumen/000_default/result/result_reward","dummy_reward")						-- ごほうび
		end,

		----------------------------------------
		-- その他

		-- AIドンの初期化
		InitDonAI = function(this)
			Debug.PrintString("[AiResultSectionMain] InitDonAI")

			Don.ChangeDefaultDon(1, Don.kType_AI)
			Don.SetLoopAnimation(1,"select_loop",true)
			Don.CameraReverse(1, true)

			this.mc_.ai_mc:SetText("tx_versus","ai_result_rival_name")		-- 対戦相手の名前 TODO:後でwordListに登録したものに変える
			--this.mc_.ai_mc:SetText("tx_versus","ai_result_rival_name_default")		-- 対戦相手名のデフォルト設定
		end,

		-- どんモーション再生
		StartDonAIMotion = function(this)
			donSide = 0
			if(g_result_ == kWin)then
				-- AIどんに勝ち:miss6
				Don.SetLoopAnimation(1,"miss6",true)
			elseif(g_result_ == kLose)then
				-- AIどんが勝ち:kusu_nobeat_p2
				Don.SetLoopAnimation(1,"kusu_nobeat_p2",true)
			end

			--if(g_result_ == 0)then
			--	-- AIどんに勝ち:miss6
			--	Don.SetLoopAnimation(1,"miss6",true)
			--
			--elseif(g_result_ == 1)then
			--	-- AIどんに完勝:result_percious_loop
			--	Don.SetLoopAnimation(1,"result_percious_loop",true)
			--
			--elseif(g_result_ == 2)then
			--	-- AIどんが勝ち:kusu_nobeat_p2
			--	Don.SetLoopAnimation(1,"kusu_nobeat_p2",true)
			--
			--elseif(g_result_ == 3)then
			--	-- AIどんが完勝:full_combo
			--	Don.SetLoopAnimation(1,"full_combo",true)
			--	
			--end
		end,

		-- プレイヤーどんモーションを待機モーションに戻す
		StayDonMotion = function(this)
			Don.SetLoopAnimation(0,"result_loop",true)
		end,

		-- 区間勝敗の初期設定
		SetSimple = function(this)
			Debug.PrintString("[AiResultSectionMain] SetUpSimple")

			local mc = this.mc_.ai_mc.ai_section_simple_mc
			this.isEndSimple_		= false
			this.simpleIndex_		= 1
			this.nowSectionIndex_	= this.kResult

			-- 表示数の設定
			if(g_sectionMax_ == kAISectionNum)then
				mc:GotoAndStop("section_5")
			elseif(g_sectionMax_ == kAISectionMinNum)then
				mc:GotoAndStop("section_3")
			end
			
			-- 表示アイコンの初期化
			for idx = 1, g_sectionMax_ do
				local simple	= mc:GetChildMc("simple_mc_"..idx,true)
				local label		= mc:GetChildMc("com_label_tx_mc_"..idx,true)
				simple:GotoAndStop("init")
				label:SetText("tx_section","ai_song_select_section_"..idx)		-- TODO:後で変える
			end
		end,

		-- 区間勝敗の再生
		UpdateSimple = function(this)
			--local mc = this.mc_.ai_mc.ai_section_simple_mc:GetChildMc("simple_mc_"..this.simpleIndex_,true)
			--
			--if(mc:IsInCurrentLabelMc("", "init"))then
			--	-- 開始
			--	if(g_sectionResult_[this.simpleIndex_] == kWin)then
			--		mc:GotoAndPlay("win_in")
			--	elseif(g_sectionResult_[this.simpleIndex_] == kLose)then
			--		mc:GotoAndPlay("lose_in")
			--	end
			--	TSound:Play("se_airesult_v12g","section")		-- SE:区間勝利アイコン表示
			--elseif(mc:IsInCurrentLabelMc("", "win") or mc:IsInCurrentLabelMc("", "lose"))then
			--	-- 完了時
			--	if(this.simpleIndex_ == g_sectionMax_)then
			--		-- 全てのアイコンが完了した場合
			--		this.isEndSimple_ = true
			--		this.timer_ = 0
			--	else
			--		-- 次のアイコン
			--		this.simpleIndex_ = this.simpleIndex_+1
			--	end
			--end

			-- 改修後
			local mc = this.mc_.ai_mc.ai_section_simple_mc:GetChildMc("simple_mc_"..this.simpleIndex_,true)
			if(mc:IsInCurrentLabelMc("", "init"))then
				-- 開始
				for idx = 1, g_sectionMax_ do
					idxMc = this.mc_.ai_mc.ai_section_simple_mc:GetChildMc("simple_mc_"..idx,true)
					if(g_sectionResult_[idx] == kWin)then
						idxMc:GotoAndPlay("win_in")
					elseif(g_sectionResult_[idx] == kLose)then
						idxMc:GotoAndPlay("lose_in")
					end
				end
				TSound:Play("se_airesult_v12g","section")		-- SE:区間勝利アイコン表示
			elseif(mc:IsInCurrentLabelMc("", "win") or mc:IsInCurrentLabelMc("", "lose"))then
				-- 完了時
				this.isEndSimple_ = true
				this.timer_ = 0
			end
		end,

		-- 区間勝敗のスキップ
		SkipSimple = function(this)
			Debug.PrintString("[AiResultSectionMain] SkipSimple")
			if(this.isEndSimple_ == false)then
				local mc
				for idx = 1, g_sectionMax_ do
					mc = this.mc_.ai_mc.ai_section_simple_mc:GetChildMc("simple_mc_"..idx,true)
					if(g_sectionResult_[idx] == kWin)then
						mc:GotoAndStop("win")
					elseif(g_sectionResult_[idx] == kLose)then
						mc:GotoAndStop("lose")
					end
				end
				this.isEndSimple_ = true
			end
		end,

		-- 勝敗アイコンの初期設定
		SetResultIcon = function(this)
			Debug.PrintString("[AiResultSectionMain] SetResultIcon")
			this.isEndResultIcon_ = false
			this.mc_.battle_win_mc:GotoAndStop("in")
			this.mc_.battle_lose_mc:GotoAndStop("in")
		end,

		-- 勝敗アイコンの再生
		StartResultIcon = function(this)
			if(g_result_ == kWin)then
				-- 勝利時
				this.mc_.battle_win_mc:GotoAndPlay("in")
				TSound:Play("se_airesult_v12g","win")			-- SE:勝敗アイコン、勝利時
			else
				-- 敗北時
				this.mc_.battle_lose_mc:GotoAndPlay("in")
				TSound:Play("se_airesult_v12g","lose")			-- SE:勝敗アイコン、敗北時
			end
		end,

		-- 勝敗アイコンの更新
		UpdateResultIcon = function(this)
			if(g_result_ == kWin)then
				-- 勝利時
				if(this.mc_.battle_win_mc:IsInCurrentLabelMc("","loop"))then
					-- 終了
					this.isEndResultIcon_ = true
				end
			else
				-- 敗北時
				if(this.mc_.battle_lose_mc:IsInCurrentLabelMc("","loop"))then
					-- 終了
					this.isEndResultIcon_ = true
				end
			end
		end,

		-- 勝敗アイコンのスキップ
		SkipResultIcon = function(this)
			Debug.PrintString("[AiResultSectionMain] SkipResultIcon")
			if(this.isEndResultIcon_ == false)then
				if(g_result_ == kWin)then
					-- 勝利時
					this.mc_.battle_win_mc:GotoAndPlay("loop")
				else
					-- 敗北時
					this.mc_.battle_lose_mc:GotoAndPlay("loop")
				end
				this.isEndResultIcon_ = true
			end
		end,

		-- 区間詳細の初期設定
		SetSectionDeteil = function(this)
			Debug.PrintString("[AiResultSectionMain] SetSectionDeteil")

			-- 表示数の設定
			if(g_sectionMax_ == kAISectionNum)then
				this.mc_.ai_mc.ai_section_detail_mc:GotoAndStop("section_5")
			elseif(g_sectionMax_ == kAISectionMinNum)then
				this.mc_.ai_mc.ai_section_detail_mc:GotoAndStop("section_3")
			end

			Debug.PrintString("区間数:"..g_sectionMax_)
			for idx = 1, g_sectionMax_ do
				Debug.PrintString("スコアてすと")
				
				-- mc設定
				this.mcSectionDeteil_[idx] = this.mc_.ai_mc.ai_section_detail_mc:GetChildMc("detail_mc_"..idx,true)
				this.mcSectionDeteil_[idx]:GotoAndStop("init")

				-- テキスト設定
				this.mcSectionDeteil_[idx].com_label_tx_mc:SetText("tx_section","ai_song_select_section_"..idx)		-- 区間 TODO:後で変える
				this.mcSectionDeteil_[idx]:SetText("tx_score","result_score")										-- スコア
				this.mcSectionDeteil_[idx].best_score_mc:SetText("tx_bestscore","ai_result_bestscore")				-- ベストスコア

				-- 勝敗
				if(g_sectionResult_[idx] == kWin)then
					this.mcSectionDeteil_[idx].detail_icon_badge_mc:GotoAndStop("win")
				elseif(g_sectionResult_[idx] == kLose)then
					this.mcSectionDeteil_[idx].detail_icon_badge_mc:GotoAndStop("lose")
				end

				-- 王冠
				if(g_sectionCrown_[idx] == 0)then
					this.mcSectionDeteil_[idx].detail_icon_crown_mc:GotoAndStop("none")
				elseif(g_sectionCrown_[idx] == 1)then
					this.mcSectionDeteil_[idx].detail_icon_crown_mc:GotoAndStop("crown_silver")
				elseif(g_sectionCrown_[idx] == 2)then
					this.mcSectionDeteil_[idx].detail_icon_crown_mc:GotoAndStop("crown_gold")
				elseif(g_sectionCrown_[idx] == 3)then
					this.mcSectionDeteil_[idx].detail_icon_crown_mc:GotoAndStop("crown_rainbow")
				end

				-- スコア
				this.scoreNum_[idx]			= AiResultScoreCounter.New("totalScore")
				this.scoreNumBack_[idx]		= AiResultScoreCounter.New("totalScoreBack")
				this.scoreNum_[idx]:Init(this.mcSectionDeteil_[idx].detail_score_front_mc, 7, g_sectionScore_[idx])
				this.scoreNumBack_[idx]:Init(this.mcSectionDeteil_[idx].detail_score_back_mc, 7, g_sectionScore_[idx])

				this.scoreNum_[idx]:SkipCounter()
				this.scoreNumBack_[idx]:SkipCounter()

				-- 良、可、不可、連打数
				this.goodNum_[idx]				= AiResultScoreCounter.New("goodNum")
				this.okNum_[idx]				= AiResultScoreCounter.New("okNum")
				this.badNum_[idx]				= AiResultScoreCounter.New("badNum")
				this.dramrollNum_[idx]			= AiResultScoreCounter.New("dramrollNum")

				this.goodNum_[idx]:Init(this.mcSectionDeteil_[idx].detail_count_mc_1, 4, g_sectionGoodNum_[idx])
				this.okNum_[idx]:Init(this.mcSectionDeteil_[idx].detail_count_mc_2, 4, g_sectionOkNum_[idx])
				this.badNum_[idx]:Init(this.mcSectionDeteil_[idx].detail_count_mc_3, 4, g_sectionBadNum_[idx])
				this.dramrollNum_[idx]:Init(this.mcSectionDeteil_[idx].detail_count_mc_4, 4, g_sectionDramrollNum_[idx])

				this.goodNum_[idx]:SkipCounter()
				this.okNum_[idx]:SkipCounter()
				this.badNum_[idx]:SkipCounter()
				this.dramrollNum_[idx]:SkipCounter()

				-- ベスト演出用
				-- ベスト:スコア
				if(g_sectionTotalBestScore_[idx] ~= 0 and g_sectionScore_[idx] > g_sectionTotalBestScore_[idx] and g_isBestScore_ == true and g_isAllOnpuEnd_ == true) then
					local updateScore = g_sectionScore_[idx] - g_sectionTotalBestScore_[idx]
					this.isNewRecord_[idx] = true
					this.mcSectionDeteil_[idx].best_score_mc:GotoAndStop("on")
					this.mcSectionDeteil_[idx].best_score_mc:SetVisible(true)
					
					this.bestScore_[idx] = AiResultScoreCounter.New("bestScore")
					this.bestScore_[idx]:Init(this.mcSectionDeteil_[idx].best_score_mc.best_score_num, 7, updateScore)
					this.bestScore_[idx]:SkipCounter()
				else
					this.isNewRecord_[idx] = false
					this.mcSectionDeteil_[idx].best_score_mc:GotoAndStop("off")
					this.mcSectionDeteil_[idx].best_score_mc:SetVisible(false)
				end

				-- ベスト:良、可、不可、連打数
				-- 良
				if(g_sectionBestGoodNum_[idx] ~= 0 and g_sectionGoodNum_[idx] > g_sectionBestGoodNum_[idx] and g_isBestScore_ == true and g_isAllOnpuEnd_ == true) then
					local updateScore = g_sectionGoodNum_[idx] - g_sectionBestGoodNum_[idx]
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_1:GotoAndStop("on")
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_1:SetVisible(true)
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_1.detail_count_data_pm_mc:GotoAndStop("plus")

					this.bestGoodNum_[idx] = AiResultScoreCounter.New("bestGoodNum")
					this.bestGoodNum_[idx]:Init(this.mcSectionDeteil_[idx].detail_count_data_set_mc_1.best_score_num, 4, updateScore)
					this.bestGoodNum_[idx]:SkipCounter()
				else
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_1:GotoAndStop("off")
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_1:SetVisible(false)
				end

				-- 可
				if(g_sectionBestOkNum_[idx] ~= 0 and g_sectionOkNum_[idx] < g_sectionBestOkNum_[idx] and g_isBestScore_ == true and g_isAllOnpuEnd_ == true) then
					local updateScore = g_sectionBestOkNum_[idx] - g_sectionOkNum_[idx]
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_2:GotoAndStop("on")
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_2:SetVisible(true)
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_2.detail_count_data_pm_mc:GotoAndStop("minus")

					this.bestOkNum_[idx] = AiResultScoreCounter.New("bestOkNum")
					this.bestOkNum_[idx]:Init(this.mcSectionDeteil_[idx].detail_count_data_set_mc_2.best_score_num, 4, updateScore)
					this.bestOkNum_[idx]:SkipCounter()
				else
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_2:GotoAndStop("off")
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_2:SetVisible(false)
				end

				-- 不可
				if(g_sectionBestBadNum_[idx] ~= 0 and g_sectionBadNum_[idx] < g_sectionBestBadNum_[idx] and g_isBestScore_ == true and g_isAllOnpuEnd_ == true) then
					local updateScore = g_sectionBestBadNum_[idx] - g_sectionBadNum_[idx]
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_3:GotoAndStop("on")
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_3:SetVisible(true)
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_3.detail_count_data_pm_mc:GotoAndStop("minus")

					this.bestBadNum_[idx] = AiResultScoreCounter.New("bestBadNum")
					this.bestBadNum_[idx]:Init(this.mcSectionDeteil_[idx].detail_count_data_set_mc_3.best_score_num, 4, updateScore)
					this.bestBadNum_[idx]:SkipCounter()
				else
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_3:GotoAndStop("off")
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_3:SetVisible(false)
				end

				-- 連打数
				if(g_sectionBestDramrollNum_[idx] ~= 0 and g_sectionDramrollNum_[idx] > g_sectionBestDramrollNum_[idx] and g_isBestScore_ == true and g_isAllOnpuEnd_ == true) then
					local updateScore = g_sectionDramrollNum_[idx] - g_sectionBestDramrollNum_[idx]
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_4:GotoAndStop("on")
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_4:SetVisible(true)
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_4.detail_count_data_pm_mc:GotoAndStop("plus")

					this.bestDramrollNum_[idx] = AiResultScoreCounter.New("bestDramrollNum")
					this.bestDramrollNum_[idx]:Init(this.mcSectionDeteil_[idx].detail_count_data_set_mc_4.best_score_num, 4, updateScore)
					this.bestDramrollNum_[idx]:SkipCounter()
				else
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_4:GotoAndStop("off")
					this.mcSectionDeteil_[idx].detail_count_data_set_mc_4:SetVisible(false)
				end

			end
		end,

		-- 区間詳細の開始
		StartSectionDeteil = function(this)
			for idx = 1, g_sectionMax_ do
				this.mcSectionDeteil_[idx]:GotoAndPlay("fade_in")
			end
		end,

		-- 区間詳細の王冠演出開始
		StartSectionDeteilCrown = function(this)
			for idx = 1, g_sectionMax_ do
				this.mcSectionDeteil_[idx]:GotoAndPlay("crown_in")
			end
		end,

		-- 操作ガイドの設定
		SetGuide = function(this)
			Debug.PrintString("[AiResultSectionMain] SetGuide")
			--this.mcGuide_:GotoAndStop("init")
			--this.mcGuide_.guide_taiko_mc:GotoAndStop("init")
			--this.mcGuide_.guide_taiko_mc.select_instance.text_guide_instance:SetText("text_guide","ai_result_detail")	-- 「詳細」
			--this.mcGuide_.guide_taiko_mc.decide_instance.text_guide_instance:SetText("text_guide","decide")

			-- 元の
			this.mc_.dummy_guide.main:GotoAndStop("init")
			this.mc_.dummy_guide.main.guide_taiko_mc:GotoAndStop("next")
			this.mc_.dummy_guide.main.guide_taiko_mc.select_instance.text_guide_instance:SetText("text_guide","ai_result_detail")	-- 「詳細」
			--this.mc_.dummy_guide.main.guide_taiko_mc.decide_instance.text_guide_instance:SetText("text_guide","decide")				-- 「決定」
		end,

		-- 操作ガイドの開始
		StartGuide = function(this)
			--this.mcGuide_:GotoAndPlay("start")
			--this.mcGuide_.guide_taiko_mc:GotoAndStop("init")
			--this.mcGuide_.guide_taiko_mc.select_instance.text_guide_instance:SetText("text_guide","ai_result_detail")	-- 「詳細」

			-- 元の
			this.mc_.dummy_guide.main:GotoAndPlay("start")
			this.mc_.dummy_guide.main.guide_taiko_mc:GotoAndStop("next")
			this.isGuideEnd_ = false
			
		end,

		-- 操作ガイドの開始
		UpdateGuide = function(this)
			if(this.isGuideEnd_ == false and this.timer_ > 120)then
				this.isGuideEnd_ = true
				TSound:Play("se_airesult_v12g","number_window_open")		-- SE:操作ガイド開始音
			end
		end,

		-- 操作ガイドフェードアウト
		FadeOutGuide = function(this)
			--this.mcGuide_:GotoAndPlay("end")
			
			-- 元の
			--this.mc_.dummy_guide.main.guide_taiko_mc:GotoAndPlay("fade_out")
			this.mc_.dummy_guide.main:GotoAndPlay("end")
		end,

		-- 勝敗と詳細の切り替え
		SwitchSection = function(this)
			if(this.mc_.ai_mc:IsInCurrentLabelMc("","simple") or this.mc_.ai_mc:IsInCurrentLabelMc("","deitail"))then
				
				if(this.nowSectionIndex_ == this.kResult)then
					-- 勝敗から詳細に切り替え
					this.nowSectionIndex_ = this.kDetail
					--this.mcGuide_.guide_taiko_mc.select_instance.text_guide_instance:SetText("text_guide","ai_result_back")	-- 「戻る」
					-- 元の
					this.mc_.dummy_guide.main.guide_taiko_mc.select_instance.text_guide_instance:SetText("text_guide","ai_result_back")	-- 「戻る」
					
					this.mc_.ai_mc:GotoAndPlay("change_to_detail")
					this:StartSectionDeteilCrown()

				elseif(this.nowSectionIndex_ == this.kDetail)then
					-- 詳細から勝敗に切り替え
					this.nowSectionIndex_ = this.kResult
					--this.mcGuide_.guide_taiko_mc.select_instance.text_guide_instance:SetText("text_guide","ai_result_detail")	-- 「詳細」
					-- 元の
					this.mc_.dummy_guide.main.guide_taiko_mc.select_instance.text_guide_instance:SetText("text_guide","ai_result_detail")	-- 「詳細」
					
					this.mc_.ai_mc:GotoAndPlay("change_to_simple")

				end

				-- サウンド再生
				TSound:Play("se_common_v12a","katsu_c")
			end
		end,

		-- 合計勝利数の設定
		SetTotalWinCount = function(this)
			Debug.PrintString("[AiResultSectionMain] SetTotalWinCount")
			this.isEndWinCount_ = false

			-- g_winCountDisplay_の設定
			if(g_aiGetRewardNum >= 1)then
				-- ご褒美がある
				this.nextRewardIndex_ = 1
			else
				-- ない
				if(g_aiNoticeRewardNum >= 1)then
					this.nextRewardIndex_ = g_aiRewardNoticeTokenNeedPoint[1] - g_winCount_
					if(g_result_ == kWin)then
						this.nextRewardIndex_ = this.nextRewardIndex_ + 1
					end
				else
					this.nextRewardIndex_ = 0
				end
			end

			-- g_winCountDisplay_の設定
			if(g_aiNoticeRewardNum >= 1 or g_aiGetRewardNum >= 1)then
				-- 次のご褒美がある or ご褒美がある
				g_winCountDisplay_ = kWinCountReward
			else
				-- どちらもない
				g_winCountDisplay_ = kWinCountDisplay
			end

			if(g_isCardUser_ == false)then
				g_winCountDisplay_ = kWinCountNone
			end

			-- 勝利数
			local winCount = g_winCount_
			if(winCount > this.kWinCountMax_)then
				winCount = this.kWinCountMax_
			elseif(g_result_ == kWin)then
				winCount = winCount - 1
			end

			-- 現在の勝利数の設定
			this.totalWinNum_ = AiResultWinCounter.New("totalWin")
			this.totalWinNum_:Init(this.mc_.win.num_total_wins, 6, winCount)
			this.totalWinNum_:SetCounter()
			this.mc_.win.text_total_wins:SetText("text_total_wins","ai_song_select_total_wins")

			if(g_winCountDisplay_ == kWinCountReward)then
				-- 次のごほうびまでの勝利数を出す場合
				this.mc_.win:GotoAndStop("normal")
				this.NextRewardNum_	= AiResultWinCounter.New("nextReward")
				this.NextRewardNum_:Init(this.mc_.win.num_next_reward, 4, this.nextRewardIndex_)
				this.NextRewardNum_:SetCounter()
				this.mc_.win.text_next_reward:SetText("text_next_reward","ai_song_select_need_wins")

				-- 勝利数カウンター設定
				this.aiResultWinCountMain_:SetWinCounter(this.NextRewardNum_)
			else
				this.mc_.win:GotoAndStop("max")
			end

			this.winCountState_ = this.kWinCountState.Fadein_
		end,

		-- 合計勝利数の開始
		StartTotalWinCount = function(this)
			Debug.PrintString("[AiResultSectionMain] StartTotalWinCount")
			this.mc_:GotoAndPlay("win_count_in")
			TSound:Play("se_airesult_v12g","number_window_open")		-- SE:勝利数ウィンドウ表示時
		end,

		-- 合計勝利数の更新
		UpdateTotalWinCount = function(this)
			if(this.winCountState_ == this.kWinCountState.Fadein_)then
				if(this.timer_ > 240)then
					this.timer_ = 0
					if(g_result_ == kWin)then
						this.winCountState_ = this.kWinCountState.TotalWin_
						if(g_result_ == kWin and g_winCount_ <= this.kWinCountMax_)then
							TSound:Play("se_common_v12a","count_stop_c")		-- SE:勝利数カウント時
							this.totalWinNum_:DirectCounter(g_winCount_)
						end
					else
						this.winCountState_ = this.kWinCountState.Flash_
					end
				end
			elseif(this.winCountState_ == this.kWinCountState.TotalWin_)then
				if(this.timer_ > 120)then
					this.timer_ = 0
					if(g_winCountDisplay_ == kWinCountReward)then
						this.winCountState_ = this.kWinCountState.NextReward_
						if(g_result_ == kWin)then
							this.NextRewardNum_:DirectCounter(this.nextRewardIndex_-1)
							TSound:Play("se_common_v12a","count_stop_c")		-- SE:次のご褒美までの勝利数カウント時
						end
					else
						this.winCountState_ = this.kWinCountState.Flash_
					end
				end
			elseif(this.winCountState_ == this.kWinCountState.NextReward_)then
				if(this.timer_ > 120)then
					-- 勝利数カウント後 or 次のご褒美までの勝利数カウント後
					this.timer_ = 0
					this.winCountState_ = this.kWinCountState.Flash_
					this.mc_.win:GotoAndPlay("normal_flash")
					TSound:Play("se_airesult_v12g","number_window_shine")		-- SE:フラッシュ演出時
					if(g_winCountDisplay_ == kWinCountReward and this.nextRewardIndex_-1 == 0 and g_result_ == kWin)then
						-- 目標達成時
						TSound:Play("voice_airesult_v12g","achieve_number")		-- ボイス:「すごいです～！」
					end
				end
			elseif(this.winCountState_ == this.kWinCountState.Flash_)then
				if(this.timer_ > 80)then
					this.isEndWinCount_ = true
				end
			end
		end,

		-- 合計勝利数のスキップ演出
		SkipTotalWinCount = function(this)
			Debug.PrintString("[AiResultSectionMain] SkipTotalWinCount")
			if(this.isEndWinCount_ == false)then
				this.mc_:GotoAndStop("win_count_end")
				this.mc_.win:GotoAndStop("normal_flash_end")
				--this.mc_.win:GotoAndPlay("normal_flash")

				if(g_result_ == kWin and g_winCount_ <= this.kWinCountMax_)then
					this.totalWinNum_:DirectCounter(g_winCount_)
					this.NextRewardNum_:DirectCounter(this.nextRewardIndex_-1)
				end

				this.isEndWinCount_ = true
			end
		end,

		-- 合計勝利数の終了
		EndTotalWinCount = function(this)
			Debug.PrintString("[AiResultSectionMain] EndTotalWinCount")
			this.mc_:GotoAndPlay("win_count_fade")
		end,
	}
end
