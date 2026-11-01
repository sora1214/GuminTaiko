-- AiPlayAllMain.lua
-- AIバトル総合プレイ結果画面

-- 使うクラスを読み込む
require("common.Sound")
require("common.State")
require("common.Timer")
require("common.ResultSoloModeQRcodeWindow")
require("ai_play_all.AiPlayAllWindow")

-- このクラス
AiPlayAllMain = {

	-- 定数
	kWaitOshimaiTime_ = 7,	-- ゲームオーバーの「また遊んでね」での待機時間
	kWaitCopyrightTime_ = 3,	-- ゲームオーバー後のコピーライトでの待機時間

	-- 変数
	state_		= State.New("AiPlayAllMain"),
	aiPlayAllWindow,			-- 総合プレイ結果画面

	now_count_ = 0,					-- ゲームオーバー用タイマ
	now_count_decimal_ = 0,			-- タイマの小数点以下を数える
	isStartGameOver_ = false,		-- ゲームオーバ演出が開始したか否か
	isFinishGameOver_ = false,		-- ゲームオーバ演出が終了したか否か
	isFinishSendNetwork_ = false,	-- サーバ送信が終了したか否か

	qrcodeTimer_ = Timer.New( "dummy_qrcode_image_timer" ), -- QR コードタイマー
	qrcodeWindow_ = ResultSoloModeQRcodeWindow.New( "dummy_qrcode_image_window" ), -- QRコードウィンドウ

	kQRCodeTimerInitVal_ = 50, -- QR コードタイマー初期値
	kQRCodeTimerSoundVoiceSlotNo_ = 5, -- QRコードのカウントダウンタイマーのボイスのスロット番号

	-- ムービークリップ
	mc_,					-- メインmc
	gameOverMc_,			-- ゲームオーバーmc

	----------------------------------------
	-- state処理
	Init = function(this)
		-- 全体シーケンス
		this.state_.func_["Begin"] = function()
			-- 開始
			Debug.PrintString("[AiPlayAllMain] Begin")
			this.aiPlayAllWindow	= AiPlayAllWindow.New()

			-- LoadMovie
			Lumen.LoadMovie("lumen/000_default/enso_ai/result/result_ai_playall","dummy_result")	-- 総合プレイ結果
			Lumen.LoadMovie("lumen/000_default/gameover/GameOver","dummy_gameover")					-- ゲームオーバー演出

			-- QRコード関連のムービークリップ
			this.qrcodeTimer_:LoadMovie()
			this.qrcodeWindow_:LoadMovie()

			-- ダミーの読み込み
			this.state_:SetState("Loading")
		end

		this.state_.func_["Loading"] = function()
			-- 読み込み待ち

			if (Lumen.IsLoadMovieFinish() == true) then
				Debug.PrintString("[AiPlayAllMain] Loading Finish")

				-- Lumen.IsLoadMovieFinish() を見て初期化してるところがあるので他の Lumen のロードよりも前に設定する
				this.qrcodeTimer_:Setup( 9 )
				this.qrcodeTimer_:SoundSetting( true, true )
				this.qrcodeTimer_:SetSoundVoiceSlotNo( this.kQRCodeTimerSoundVoiceSlotNo_ )
				this.qrcodeTimer_:SetVisible( false )
				this.qrcodeTimer_:SetShadow( false )
				this.qrcodeTimer_:SetCount( this.kQRCodeTimerInitVal_ )
				this.qrcodeWindow_:Setup()

				-- 各ダミー内の読み込み
				this.mc_ = Lumen.GetMovieClip("main",true)
				this.aiPlayAllWindow:LoadMovie()

				-- qrcodeWindow_ にロードするムービークリップ
				this.qrcodeWindow_:LoadChildMovie()

				this.state_:SetState("LoadingDummy")
				return
			end
			Debug.PrintString("[AiPlayAllMain] Loading Wait...")
		end

		this.state_.func_["LoadingDummy"] = function()
			-- ダミー内の読み込み待ち

			if (Lumen.IsLoadMovieFinish() == true) then
				Debug.PrintString("[AiPlayAllMain] LoadingDummy Finish")
				-- 読み込み完了後

				-- qrcodeWindow_ にロードするムービークリップ
				this.qrcodeWindow_:SetupChild()

				-- MovieClip
				this.aiPlayAllWindow:SetUp(this.mc_.dummy_result)
				Common.LuaPrepareFinish()
				this.state_:SetState("SetUp")
				return
			end
			Debug.PrintString("[AiPlayAllMain] LoadingDummy Wait...")
		end

		this.state_.func_["SetUp"] = function()
			-- 初期設定
			Debug.PrintString("[AiPlayAllMain] SetUp")
			this.state_:SetState("StartWait")
			this.aiPlayAllWindow:Init()
		end

		this.state_.func_["StartWait"] = function()
			-- 開始待ち

			if(FadeFlag == false)then
				Debug.PrintString("[AiPlayAllMain] StartWait Finish")
				this.state_:SetState("PlayAllMain")
				TSound:Play("bgm_airesult_v12g","total_loop")		-- BGM:プレイ結果まとめ
				TSound:Play("voice_airesult_v12g","announce_total")	-- ボイス:「今回のまとめです」
			end
		end

		this.state_.func_["PlayAllMain"] = function()
			-- 総合プレイ結果画面

			if(this.aiPlayAllWindow.isEnd_ == true)then
				-- Debug.PrintString("[AiPlayAllMain] PlayAllMain Finish")
				-- this:StartGameOver()
				-- this.state_:SetState("GameOver")
				-- return

				-- QRコード画像が有効なら表示シーケンスへ、無効なら終了へ
				if ( g_isQRCodeImageValid == true ) then
					this.state_:SetState("QRCodeImage")
				else
					this:StartGameOver()
					this.state_:SetState("GameOver")
				end
				return
			end

			-- 更新
			this.aiPlayAllWindow:Update()
		end

		this.state_.func_["QRCodeImage"] = function()
			this.qrcodeTimer_:SetVisible( true )
			this.qrcodeTimer_:StartCount()

			this.qrcodeWindow_:PlayStart()

			this.state_:SetState("QRCodeImage_Proc")
		end

		this.state_.func_["QRCodeImage_Proc"] = function()
			-- タイマー０で終了へ
			this.qrcodeTimer_:Update()
			local qrcode_image_end = ( this.qrcodeTimer_:IsZero() == true )

			if ( ( qrcode_image_end == false ) ) then
				-- ドンが叩かれていたらタイマーのカウントを減らす
				local  input_flag = false
				if ( g_joinSide_ == 1 ) then  -- 左側１人プレイの場合
					input_flag = ( Input.GetTrigger( Input.PLAYER1_OK ) == true ) or ( Input.GetTrigger( Input.PLAYER1_CANCEL ) == true )
				elseif ( g_joinSide_ == 2 ) then  -- 右側１人プレイの場合
					input_flag = ( Input.GetTrigger( Input.PLAYER2_OK ) == true ) or ( Input.GetTrigger( Input.PLAYER2_CANCEL ) == true )
				end
				if ( input_flag ) then
					-- ドンが叩かれていたら Timer の decimal を 1 にする→次の Update() で 0 になる
					local timer_count = this.qrcodeTimer_:GetCount()
					this.qrcodeTimer_:SetCountAndDecimal( timer_count, 1 )
					-- 終了の音は終了してから鳴らすのでここで鳴らさない
					if ( 1 < timer_count ) then
						-- １人プレイ時は don_c を鳴らす
						TSound:Play("se_common_v12a","don_c")
					end
				end
			end

			if (  qrcode_image_end  ) then
				-- 終了で音を鳴らす(２人プレイでも中央のみ)
				TSound:Play("se_common_v12a","don_big")

				this:StartGameOver()
				this.state_:SetState("GameOver")
			end
		end

		this.state_.func_["GameOver"] = function()
			-- ゲームオーバー
			--Debug.PrintString("[AiPlayAllMain] GameOver Finish")
			--this.state_:SetState("End")
			if(this.isFinishGameOver_ == true)then
				Debug.PrintString("[AiPlayAllMain] GameOver Finish")
				this.state_:SetState("End")
			end
			this:UpdateGameOver()
		end

		this.state_.func_["End"] = function()
			Debug.PrintString("[AiPlayAllMain] End")
			Common.LuaFinish()
		end
	end,

	-- 更新
	Update = function(this)
		-- ステート処理
		this.state_:Update()
	end,

	----------------------------------------
	-- その他

	-- ゲームオーバー演出開始処理
	StartGameOver = function(this)
		Debug.PrintString("[AiPlayAllMain] StartGameOver")

		this.mc_.dummy_gameover.main:GotoAndStop("start")
		this.mc_.dummy_gameover.main.end_curtain_mc:GotoAndPlay("oshimai_start")
		
		-- サウンド
		TSound:StopBank("bgm_airesult_v12g")
		TSound:Play("se_common_v12a","curtain")
		TSound:Play("bgm_common_v12a","gameover_primal")
		TSound:Play("voice_common_v12a","gameover")
		
		-- サーバ送信
		if(this.isFinishSendNetwork_ == false) then
			-- 【！！！注意！！！】　サーバ送信の際はプレイ人数に関わらず、左側の太鼓：0、右側の太鼓：1、になります！
			if(g_joinSide_ == 1)then
				Debug.PrintString("[AiPlayAllMain] StartSendResult")
				NetAccess.SendAiResultData(0)
			elseif(g_joinSide_ == 2)then
				Debug.PrintString("[AiPlayAllMain] StartSendResult")
				NetAccess.SendAiResultData(1)
			end

			-- ＱＲ使用
			QR.StartQRExecAll(SceneType.kResult)

			this.isFinishSendNetwork_ = true
		end

		this.now_count_decimal_ = Common.FPS	-- 何フレームを１秒とするか、ここで初期化（FPSには60とか120とかの値が入ってます）
		this.isStartGameOver_ = true
	end,
	-- ここまでStartGameOver

	-- ゲームオーバー演出更新処理
	UpdateGameOver = function(this)
		-- 「ＱＲ使用」の終了待ち
		local qr_exec_finish = false
		if(QR.ProcExecQRAll() ~= GameConnectStatus.kDoing) then
			qr_exec_finish = true
		end

		--　タイマの更新。now_count_decimal_（= 60 or 120）を毎フレーム-1し、0になったらnow_count_を+1する
		this.now_count_decimal_ = this.now_count_decimal_ - 1
		if(this.now_count_decimal_ == 0) then
			this.now_count_decimal_ = Common.FPS
			this.now_count_ = this.now_count_ + 1
		end
		
		if(this.now_count_ >= this.kWaitOshimaiTime_ and this.now_count_ < 100) then
			this.now_count_ = 100
			this.mc_.dummy_gameover.main.end_curtain_mc:GotoAndPlay("copyright_start")
		elseif((this.now_count_ >= (100 + this.kWaitCopyrightTime_)) and (qr_exec_finish == true))	then
			this.mc_.dummy_gameover.main.end_curtain_mc:GotoAndStop("end")
			this.isFinishGameOver_ = true	-- ゲームオーバー完了フラグを起動する
		end
	end,
	-- ここまでUpdateGameOver

}
