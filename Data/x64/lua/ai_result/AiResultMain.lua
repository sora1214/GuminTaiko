-- AiResultMain.lua
-- AIバトルリザルト画面

-- 使うクラスを読み込む
require("common.Sound")
require("common.State")
require("common.NamePlate")
require("ai_result.AiResultSongMain")
require("ai_result.AiResultSectionMain")
require("ai_result.AiResultRewardMain")
require("ai_result.AiResultWinCountMain")
--require("ai_result.AiResultPlayAllMain")

-- このクラス
AiResultMain = {

	-- 定数
	kWaitOshimaiTime_ = 7,	-- ゲームオーバーの「また遊んでね」での待機時間
	kWaitCopyrightTime_ = 3,	-- ゲームオーバー後のコピーライトでの待機時間

	-- 変数
	state_		= State.New("AiResultMain"),
	namePlate_	= NamePlate.New("plate_1p_instance"),

	aiResultSongMain,				-- 演奏結果
	aiResultSectionMain,			-- 区間勝敗
	aiResultRewardMain,				-- ごほうび
	aiResultWinCountMain,			-- 勝利数ごほうび
	--aiResultPlayAllMain,			-- 総合プレイ結果画面

	now_count_ = 0,					-- ゲームオーバー用タイマ
	now_count_decimal_ = 0,			-- タイマの小数点以下を数える
	isStartGameOver_ = false,		-- ゲームオーバ演出が開始したか否か
	isFinishGameOver_ = false,		-- ゲームオーバ演出が終了したか否か
	isFinishSendNetwork_ = false,	-- サーバ送信が終了したか否か

	-- ムービークリップ
	mc_,					-- メインmc
	don1pMc_,				-- マイドン
	optionIcon_,			-- 演奏オプションアイコン
	gameOverMc_,			-- ゲームオーバーmc

	----------------------------------------
	-- state処理
	Init = function(this)
		-- 全体シーケンス
		this.state_.func_["Begin"] = function()
			-- 開始
			Debug.PrintString("[AiResultMain] Begin")
			this.aiResultSongMain		= AiResultSongMain.New()
			this.aiResultSectionMain	= AiResultSectionMain.New()
			this.aiResultRewardMain		= AiResultRewardMain.New()
			this.aiResultWinCountMain	= AiResultWinCountMain.New()
			--this.aiResultPlayAllMain	= AiResultPlayAllMain.New()

			-- LoadMovie
			Lumen.LoadMovie("lumen/000_default/result/result","dummy_play")							-- リザルト演奏結果
			Lumen.LoadMovie("lumen/000_default/enso_ai/result/result_ai_section","dummy_section")	-- 区間勝敗
			--Lumen.LoadMovie("lumen/000_default/enso_ai/result/result_ai_playall","dummy_result")	-- 総合プレイ結果
			--Lumen.LoadMovie("lumen/000_default/gameover/GameOver","dummy_gameover")					-- ゲームオーバー演出

			-- ダミーの読み込み

			this.state_:SetState("Loading")
		end

		this.state_.func_["Loading"] = function()
			-- 読み込み待ち

			if (Lumen.IsLoadMovieFinish() == true) then
				Debug.PrintString("[AiResultMain] Loading Finish")
				-- 各ダミー内の読み込み
				this.mc_ = Lumen.GetMovieClip("main",true)
				this.aiResultSongMain:LoadMovie()
				this.aiResultSectionMain:LoadMovie()
				this.aiResultRewardMain:LoadMovie()
				this.aiResultWinCountMain:LoadMovie()
				--this.aiResultPlayAllMain:LoadMovie()

				this.state_:SetState("LoadingDummy")
				return
			end
			Debug.PrintString("[AiResultMain] Loading Wait...")
		end

		this.state_.func_["LoadingDummy"] = function()
			-- ダミー内の読み込み待ち

			if (Lumen.IsLoadMovieFinish() == true) then
				Debug.PrintString("[AiResultMain] LoadingDummy Finish")
				-- 読み込み完了後

				-- MovieClip
				this.aiResultSongMain:SetUp(this.mc_.dummy_play.main, this.aiResultRewardMain)
				this.aiResultSectionMain:SetUp(this.mc_.dummy_section.main, this.aiResultRewardMain, this.aiResultWinCountMain, this.mc_.dummy_play.control_guide_L)
				this.aiResultRewardMain:SetUp(this.mc_.dummy_play.main.dummy_reward, this.mc_.dummy_play.main.event_token_bg_L, this.aiResultSongMain.namePlate_, this.mc_.dummy_play.control_guide_L)
				this.aiResultWinCountMain:SetUp(this.mc_.dummy_play.main.dummy_reward, this.mc_.dummy_section.main.dummy_reward_section, this.mc_.dummy_play.main.event_token_bg_R, this.aiResultSongMain.namePlate_, this.mc_.dummy_play.control_guide_R, this.mc_.dummy_play.control_guide_L, this.aiResultSectionMain)
				--this.aiResultPlayAllMain:SetUp(this.mc_.dummy_result)
				Common.LuaPrepareFinish()
				this.state_:SetState("SetUp")
				return
			end
			Debug.PrintString("[AiResultMain] LoadingDummy Wait...")
		end

		this.state_.func_["SetUp"] = function()
			-- 初期設定
			Debug.PrintString("[AiResultMain] SetUp")
			this.state_:SetState("StartWait")

			this.aiResultSongMain:Init()
			this.aiResultSectionMain:Init()
			this.aiResultRewardMain:Init()
			this.aiResultWinCountMain:Init()
			--this.aiResultPlayAllMain:Init()
		end

		this.state_.func_["StartWait"] = function()
			-- 開始待ち

			if(FadeFlag == false)then
				Debug.PrintString("[AiResultMain] StartWait Finish")
				this.state_:SetState("SongMain")

				TSound:Play("bgm_airesult_v12g","primal_loop")		-- BGM:AIリザルト
				TSound:Play("voice_airesult_v12g","announce")		-- ボイス:「バトル結果～」
				--this.state_:SetState("PlayAllMain")
			end
		end

		this.state_.func_["SongMain"] = function()
			-- スコア画面

			if(this.aiResultSongMain.isEnd_ == true)then
				Debug.PrintString("[AiResultMain] SongMain Finish")
				
				this.state_:SetState("SectionMain")
				return
			end

			-- 更新
			this.aiResultSongMain:Update()
		end

		this.state_.func_["SectionMain"] = function()
			-- スコア画面

			if(this.aiResultSectionMain.isEnd_ == true)then
				Debug.PrintString("[AiResultMain] SectionMain Finish")
				
				--if(g_isLastSong_ == false)then
				--	TSound:Play("se_common_v12a","don_c")
				--end
				this.state_:SetState("End")
				return
			end

			-- 更新
			this.aiResultSectionMain:Update()
		end

--		this.state_.func_["PlayAllMain"] = function()
--			-- 総合プレイ結果画面
--
--			if(this.aiResultPlayAllMain.isEnd_ == true)then
--				Debug.PrintString("[AiResultMain] PlayAllMain Finish")
--				
--				this:StartGameOver()
--				this.state_:SetState("GameOver")
--				return
--			end
--
--			-- 更新
--			this.aiResultPlayAllMain:Update()
--		end

--		this.state_.func_["GameOver"] = function()
--			-- ゲームオーバー
--			--Debug.PrintString("[AiResultMain] GameOver Finish")
--			--this.state_:SetState("End")
--			if(this.isFinishGameOver_ == true)then
--				Debug.PrintString("[AiResultMain] GameOver Finish")
--				this.state_:SetState("End")
--			end
--			this:UpdateGameOver()
--		end

		this.state_.func_["End"] = function()
			Debug.PrintString("[AiResultMain] End")
			g_isFinishAllEffect = true
			--Common.LuaFinish()
		end
	end,

	-- 更新
	Update = function(this)
		-- ステート処理
		this.state_:Update()
	end,

	----------------------------------------
	-- その他

	-- 3Dドンの初期化
	InitDon3D = function(this)
		Debug.PrintString("[AiResultMain] InitDon3D")
		
		this.mc_.don_1p:SetVisible(true)

		Don.SetLoopAnimation(0,"result_clear_loop",true)
		Don.ChangeDonForPlayData(0,Don.kType_Don)
		
	end,

--	-- ゲームオーバー演出開始処理
--	StartGameOver = function(this)
--		Debug.PrintString("[AiResultMain] StartGameOver")
--
--		this.mc_.dummy_gameover.main:GotoAndStop("start")
--		this.mc_.dummy_gameover.main.end_curtain_mc:GotoAndPlay("oshimai_start")
--		
--		-- サウンド
--		TSound:StopBank("bgm_result_v12a")
--		TSound:Play("se_common_v12a","curtain")
--		TSound:Play("bgm_common_v12a","gameover_primal")
--		TSound:Play("voice_common_v12a","gameover")
--		
--		-- サーバ送信
--		if(this.isFinishSendNetwork_ == false) then
--			-- 【！！！注意！！！】　サーバ送信の際はプレイ人数に関わらず、左側の太鼓：0、右側の太鼓：1、になります！
--			if(g_joinSide_ == 1)then
--				NetAccess.SendDojoResultData(0)
--			elseif(g_joinSide_ == 2)then
--				NetAccess.SendDojoResultData(1)
--			end
--			this.isFinishSendNetwork_ = true
--		end
--			
--		this.now_count_decimal_ = Common.FPS	-- 何フレームを１秒とするか、ここで初期化（FPSには60とか120とかの値が入ってます）
--		this.isStartGameOver_ = true
--	end,
--	-- ここまでStartGameOver
--
--	-- ゲームオーバー演出更新処理
--	UpdateGameOver = function(this)
--		--　タイマの更新。now_count_decimal_（= 60 or 120）を毎フレーム-1し、0になったらnow_count_を+1する
--		this.now_count_decimal_ = this.now_count_decimal_ - 1
--		if(this.now_count_decimal_ == 0) then
--			this.now_count_decimal_ = Common.FPS
--			this.now_count_ = this.now_count_ + 1
--		end
--		
--		if(this.now_count_ >= this.kWaitOshimaiTime_ and this.now_count_ < 100) then
--			this.now_count_ = 100
--			this.mc_.dummy_gameover.main.end_curtain_mc:GotoAndPlay("copyright_start")
--		elseif(this.now_count_ >= (100 + this.kWaitCopyrightTime_))	then
--			this.mc_.dummy_gameover.main.end_curtain_mc:GotoAndStop("end")
--			this.isFinishGameOver_ = true	-- ゲームオーバー完了フラグを起動する
--		end
--	end,
	-- ここまでUpdateGameOver

}
