-- DaniResultMain.lua
-- 段位リザルト画面

-- 使うクラスを読み込む
require("common.Sound")
require("common.State")
require("common.NamePlate")
require("common.Timer")
require("common.ResultSoloModeQRcodeWindow")
require("dani_result.DaniResultSongMain")
require("dani_result.DaniResultTotalMain")
require("dani_result.DaniResultReward")

-- このクラス
DaniResultMain = {

	-- 定数
	kWaitOshimaiTime_ = 7,		-- ゲームオーバーの「また遊んでね」での待機時間
	kWaitCopyrightTime_ = 3,	-- ゲームオーバー後のコピーライトでの待機時間

	-- 変数
	state_		= State.New("DaniResultMain"),
	namePlate_	= NamePlate.New("plate_1p_instance"),
	rewardNamePlate_,

	daniResultSong_,		-- 各曲リザルト画面
	daniResultTotal_,		-- 総合リザルト画面
	daniResultReward_,		-- 報酬画面

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
	mainMc_,				-- メインmc
	don1pMc_,				-- マイドン
	optionIcon_,			-- 演奏オプションアイコン
	gameOverMc_,			-- ゲームオーバーmc

	Init = function(this)
		-- 全体シーケンス
		this.state_.func_["Begin"] = function()
			-- 開始
			Debug.PrintString("[DaniResultMain] Begin")

			this.daniResultSong_	= DaniResultSongMain.New()
			this.daniResultTotal_	= DaniResultTotalMain.New()
			this.daniResultReward_	= DaniResultReward.New()

			-- LoadMovie
			Lumen.LoadMovie("lumen/000_default/common/option","dummy_option_icon_1p")					-- 演奏オプションアイコン
			Lumen.LoadMovie("lumen/000_default/gameover/GameOver","dummy_gameover")						-- ゲームオーバー演出
			Lumen.LoadMovie("lumen/000_default/enso_dani/result/dani_result_info","dummy_folder")		-- 段位フォルダ追加お知らせウィンドウ
			Lumen.LoadMovie("lumen/000_default/enso_dani/result/dani_shoudan","dummy_shoudan")			-- 昇段・ご褒美ウィンドウ
			Lumen.LoadMovie("lumen/000_default/enso_dani/result/dani_result_congrats","dummy_congrats")	-- 最高段位到達演出

			this.daniResultTotal_:LoadMovie()		-- ダミーの読み込み
			this.namePlate_:LoadMovie()

			-- QRコード関連のムービークリップ
			this.qrcodeTimer_:LoadMovie()
			this.qrcodeWindow_:LoadMovie()

			this.state_:SetState("Loading")
		end

		this.state_.func_["Loading"] = function()
			-- 読み込み待ち

			if (Lumen.IsLoadMovieFinish() == true) then
				Debug.PrintString("[DaniResultMain] Loading Finish")

				-- Lumen.IsLoadMovieFinish() を見て初期化してるところがあるので他の Lumen のロードよりも前に設定する
				this.qrcodeTimer_:Setup( 9 )
				this.qrcodeTimer_:SoundSetting( true, true )
				this.qrcodeTimer_:SetSoundVoiceSlotNo( this.kQRCodeTimerSoundVoiceSlotNo_ )
				this.qrcodeTimer_:SetVisible( false )
				this.qrcodeTimer_:SetShadow( false )
				this.qrcodeTimer_:SetCount( this.kQRCodeTimerInitVal_ )
				this.qrcodeWindow_:Setup()

				-- MovieClip
				this.mainMc_ = Lumen.GetMovieClip("main_mc",true)
				this.mainMc_:GotoAndStop("init")

				this.optionIcon_ = this.mainMc_:GetChildMc("dummy_option_icon_1p",true)
				this:InitOptionIcon()

				-- 読み込んだウィンドウの動きを止める
				this.mainMc_.dummy_folder:GotoAndStop("start")
				this.mainMc_.dummy_shoudan:GotoAndStop("shoudan_start")
				this.mainMc_.dummy_shoudan.don_1p:GotoAndStop("framein")		-- どんさんの初期位置
				this.mainMc_.dummy_congrats:GotoAndStop("start")

				-- 昇段ウィンドウの読み込み開始
				this.rewardNamePlate_ = NamePlate.New("nameplate_instance_1")
				this.rewardNamePlate_:LoadMovie()

				Lumen.LoadMovie("lumen/000_default/result/control_guide","dummy_control_guide_instance")								-- 操作ガイド

				-- qrcodeWindow_ にロードするムービークリップ
				this.qrcodeWindow_:LoadChildMovie()

				this.state_:SetState("LoadingShoudan")
				return
			end
			Debug.PrintString("[DaniResultMain] Loading Wait...")
		end

		this.state_.func_["LoadingShoudan"] = function()
			-- 読み込み待ち

			if (Lumen.IsLoadMovieFinish() == true) then
				Debug.PrintString("[DaniResultMain] Loading Finish")

				-- qrcodeWindow_ にロードするムービークリップ
				this.qrcodeWindow_:SetupChild()

				-- MovieClip
				this.mainMc_ = Lumen.GetMovieClip("main_mc",true)
				this.mainMc_:GotoAndStop("init")

				this.optionIcon_ = this.mainMc_:GetChildMc("dummy_option_icon_1p",true)
				this:InitOptionIcon()

				-- 読み込んだウィンドウの動きを止める
				this.mainMc_.dummy_folder:GotoAndStop("start")
				this.mainMc_.dummy_shoudan:GotoAndStop("shoudan_start")

				-- C側に準備完了通知
				Common.LuaPrepareFinish()
				this.state_:SetState("SetUp")
				return
			end
			Debug.PrintString("[DaniResultMain] Loading Wait...")
		end

		this.state_.func_["SetUp"] = function()
			-- 初期設定
			Debug.PrintString("[DaniResultMain] SetUp")

			this.daniResultSong_:Init()
			this.daniResultTotal_:Init()
			this.daniResultReward_:Init(this.rewardNamePlate_)
			this.mainMc_.shoudan_mc:GotoAndStop("in")		-- TODO:flash側で止まらないので止める
			this.mainMc_.folder_mc:GotoAndStop("in_folder")
			this.mainMc_.present_mc:GotoAndStop("in")

			-- ネームプレートの設定
			this:InitNamePlate(g_joinSide_)

			-- マイドンの設定
			this:InitDon3D()

			-- 記録対象外テキスト
			this:InitSaveText()

			this.state_:SetState("StartWait")
		end

		this.state_.func_["StartWait"] = function()
			-- 開始待ち

			if(FadeFlag == false)then
				Debug.PrintString("[DaniResultMain] StartWait Finish")
				-- 開始時のサウンドを再生
				TSound:Play("bgm_daniresult_v12e","primal_loop")	-- BGM
				TSound:Play("voice_daniresult_v12e","announce")		-- Voice:「結果発表～」
				-- clear_normal

				--voice_result_v12e
				this.state_:SetState("SongResult")
			end
		end

		this.state_.func_["SongResult"] = function()
			-- 各曲リザルト画面

			if(this.daniResultSong_.isEnd_ == true)then
				Debug.PrintString("[DaniResultMain] SongResult Finish")
				this.state_:SetState("TotalResult")
				return
			end

			this.daniResultSong_:Update()
		end

		this.state_.func_["TotalResult"] = function()
			-- 総合リザルト画面

			if(this.daniResultTotal_.isEnd_ == true)then
				Debug.PrintString("[DaniResultMain] TotalResult Finish")

				if(this.daniResultReward_:IsReward() == true)then
					-- 報酬有り
					this.state_:SetState("Reward")
				else
					-- 報酬無し
					-- this.state_:SetState("End")
--					this:StartGameOver()
--					this.state_:SetState("GameOver")

					-- QRコード画像が有効なら表示シーケンスへ、無効なら終了へ
					if ( g_isQRCodeImageValid == true ) then
						this.state_:SetState("QRCodeImage")
					else
						this:StartGameOver()
						this.state_:SetState("GameOver")
					end
				end
				return
			end

			this.daniResultTotal_:Update()
		end

		this.state_.func_["Reward"] = function()
			-- 報酬画面
			if(this.daniResultReward_.isEnd_ == true)then
				Debug.PrintString("[DaniResultMain] Reward Finish")
				--this.state_:SetState("End")
--				this:StartGameOver()
--				this.state_:SetState("GameOver")
--				return

				-- QRコード画像が有効なら表示シーケンスへ、無効なら終了へ
				if ( g_isQRCodeImageValid == true ) then
					this.state_:SetState("QRCodeImage")
				else
					this:StartGameOver()
					this.state_:SetState("GameOver")
				end
				return
			end

			this.daniResultReward_:Update()
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
			if(this.isFinishGameOver_ == true)then
				Debug.PrintString("[DaniResultMain] GameOver Finish")
				this.state_:SetState("End")
			end

			this:UpdateGameOver()
		end

		this.state_.func_["End"] = function()
			Debug.PrintString("[DaniResultMain] End")
			Common.LuaFinish()
		end
	end,

	-- 更新
	Update = function(this)
		-- ステート処理
		this.state_:Update()
	end,

	InitNamePlate = function(this, join)
		-- ネームプレートの初期化
		Debug.PrintString("[DaniResultMain] InitNamePlate")
		Debug.PrintString("join:"..join)

		this.namePlate_:Setup()
		this.namePlate_:SetVisible(true)
		this.namePlate_:SetPlayerInfo(join)

		this.rewardNamePlate_:Setup()
		this.rewardNamePlate_:SetVisible(true)
		this.rewardNamePlate_:SetPlayerInfo(join)
	end,

	InitOptionIcon = function(this)
		-- 演奏オプションアイコンの初期化
		this.optionIcon_:GotoAndStop("menu")
		local index = 0
		-- 倍速オプション
		if(g_optionSpeed_ ~= 0) then
			buffStr = "option"..index
			targetMc = this.optionIcon_:GetChildMc(buffStr,true)
			if(g_optionSpeed_ == 1) then targetMc:GotoAndStop("speedx1.1")
			elseif(g_optionSpeed_ == 2) then targetMc:GotoAndStop("speedx1.2")
			elseif(g_optionSpeed_ == 3) then targetMc:GotoAndStop("speedx1.3")
			elseif(g_optionSpeed_ == 4) then targetMc:GotoAndStop("speedx1.4")
			elseif(g_optionSpeed_ == 5) then targetMc:GotoAndStop("speedx1.5")
			elseif(g_optionSpeed_ == 6) then targetMc:GotoAndStop("speedx1.6")
			elseif(g_optionSpeed_ == 7) then targetMc:GotoAndStop("speedx1.7")
			elseif(g_optionSpeed_ == 8) then targetMc:GotoAndStop("speedx1.8")
			elseif(g_optionSpeed_ == 9) then targetMc:GotoAndStop("speedx1.9")
			elseif(g_optionSpeed_ == 10) then targetMc:GotoAndStop("speedx2")
			elseif(g_optionSpeed_ == 11) then targetMc:GotoAndStop("speedx2.5")
			elseif(g_optionSpeed_ == 12) then targetMc:GotoAndStop("speedx3")
			elseif(g_optionSpeed_ == 13) then targetMc:GotoAndStop("speedx3.5")
			elseif(g_optionSpeed_ == 14) then targetMc:GotoAndStop("speedx4")
			end
			index = index + 1
		end
		-- どろんオプション
		if(g_optionDron_ == true) then
			buffStr = "option"..index
			targetMc = this.optionIcon_:GetChildMc(buffStr,true)
			targetMc:GotoAndStop("doron")
			index = index + 1
		end
		-- あべこべオプション
		if(g_optionReverse_ == true) then
			buffStr = "option"..index
			targetMc = this.optionIcon_:GetChildMc(buffStr,true)
			targetMc:GotoAndStop("abekobe")
			index = index + 1
		end
		-- ランダムオプション
		if(g_optionRandomlv_ ~= 0) then
			buffStr = "option"..index
			targetMc = this.optionIcon_:GetChildMc(buffStr,true)
			if(g_optionRandomlv_ == 1) then targetMc:GotoAndStop("kimagure")
			elseif(g_optionRandomlv_ == 2) then targetMc:GotoAndStop("detarame")
			end
			index = index + 1
		end
		-- 音符表示位置調整オプション
		if(g_optionNoteDrawAdjust_ ~= 0) then
			buffStr = "option"..index
			targetMc = this.optionIcon_:GetChildMc(buffStr,true)
			targetMc:GotoAndStop("note_pos")
			index = index + 1
		end
	end,

	-- 3Dドンのイニシャライズ
	InitDon3D = function(this)
		Debug.PrintString("[DaniResultMain] InitDon3D")
		
		this.mainMc_.don_1p:SetVisible(true)

		Don.SetLoopAnimation(0,"result_clear_loop",true)
		Don.ChangeDonForPlayData(0,Don.kType_Don)
		
	end,

	InitSaveText = function(this)
		-- 記録対象外テキストの初期化
		Debug.PrintString("[DaniResultMain] InitSaveText")

		local flag = false
		if(g_optionSpeed_ ~= 0)then	flag = true	end			-- はやさ
		if(g_optionDron_ == true)then	flag = true	end		-- ドロン
		if(g_optionReverse_ == true)then	flag = true	end	-- あべこべ
		if(g_optionRandomlv_ ~= 0)then	flag = true	end		-- ランダム
		if(g_optionNeiro_ ~= 0)then	flag = true	end			-- 音色

		if(flag == true or g_isSkip_ == true)then
			-- オプション使用 or スキップ使用時
			this.mainMc_.save_mc:GotoAndStop("on")
			this.mainMc_.save_mc.text_nosave_info:SetText("text_nosave_info","dani_save_caution")
			g_isFolder_ = false
			g_isShodan_ = false
			Debug.PrintString("記録しません")
		else
			this.mainMc_.save_mc:GotoAndStop("off")
			Debug.PrintString("記録します")
		end
	end,



	-- ゲームオーバー演出開始処理
	StartGameOver = function(this)
		Debug.PrintString("[DaniResultMain] StartGameOver")

		this.mainMc_.dummy_gameover.main:GotoAndStop("start")
		this.mainMc_.dummy_gameover.main.end_curtain_mc:GotoAndPlay("oshimai_start")
		
		-- サウンド
		TSound:StopBank("bgm_daniresult_v12e")
		TSound:Play("se_common_v12a","curtain")
		TSound:Play("bgm_common_v12a","gameover_primal")
		TSound:Play("voice_common_v12a","gameover")
		
		-- サーバ送信
		if(this.isFinishSendNetwork_ == false) then
			-- 【！！！注意！！！】　サーバ送信の際はプレイ人数に関わらず、左側の太鼓：0、右側の太鼓：1、になります！
			if(g_joinSide_ == 1)then
				NetAccess.SendDojoResultData(0)
			elseif(g_joinSide_ == 2)then
				NetAccess.SendDojoResultData(1)
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
			this.mainMc_.dummy_gameover.main.end_curtain_mc:GotoAndPlay("copyright_start")
		elseif((this.now_count_ >= (100 + this.kWaitCopyrightTime_)) and (qr_exec_finish == true)) then
			this.mainMc_.dummy_gameover.main.end_curtain_mc:GotoAndStop("end")
			this.isFinishGameOver_ = true	-- ゲームオーバー完了フラグを起動する
		end
	end,
	-- ここまでUpdateGameOver

}
