-- 使うクラス(ライブラリ？)を読み込む
require("common.State")
require("common.Sound")
require("common.NamePlate")
require("common.Timer")
require("result.ScoreBase")
require("result.ResultBg")
require("result.ResultToken")
require("result.EventTokenBg")
require("result.ResultReward")

require("song_select.CollaboChara")


-- このクラス
Main = {
--	定数宣言
	-- 演出のシーケンス（enumもswitchも無いので、苦し紛れに定数で代用）

	kWaitOshimaiTime_ = 7,		-- ゲームオーバーの「また遊んでね」での待機時間
	kWaitCopyrightTime_ = 3,	-- ゲームオーバー後のコピーライトでの待機時間
	kRollEndTime_ = 60,			-- スコアが固まるまでにロールし続ける時間
	kWaitEffectEndTime_ = 500,	-- 全演出が終了してから入力を受け付けが再開するまでの待機時間
	kWaitMassageEndTime_ = 840,	-- コラボキャラセリフ表示時、全演出が終了してからご褒美が出るまでの時間
	kGageSpeed_ = 7,			-- 魂ゲージが１メモリ進むのに必要な時間
	kMaxGage_ = 50,				-- 魂ゲージの最大値
	
--	変数宣言
	m_State = State.New("HaraTest"),
	m_MainMc,
	bg_ = ResultBg.New("bg_mc"),
	scoreBase1p_ = ScoreBase.New("scoreBase1p"),
	scoreBase1pMc_,
	scoreBase2p_ = ScoreBase.New("scoreBase2p"),
	scoreBase2pMc_,
	tokenBase1p_ = ResultToken.New("tokenBase1p"),
	tokenBase1pMc_,
	tokenBase2p_ = ResultToken.New("tokenBase2p"),
	tokenBase2pMc_,
	rewardBase1p_ = ResultReward.New("ResultReward1p"),
	rewardBase1pMc_,
	rewardBase2p_ = ResultReward.New("ResultReward2p"),
	rewardBase2pMc_,
	eventTokenBg1p_ = EventTokenBg.New("event_token_bg_L"),
	eventTokenBg2p_ = EventTokenBg.New("event_token_bg_R"),
	namePlateL_ = NamePlate.New("name_plate_L"),
	namePlateR_ = NamePlate.New("name_plate_R"),
	collaboChara1p_ = CollaboChara.New("event1p",1),
	collaboChara2p_ = CollaboChara.New("event2p",2),
	qrcodeImageTimer_ = Timer.New("qrcode_image_timer"),
	
	don1pMc_,				-- マイドン1pMC
	don2pMc_,				-- マイドン2pMc
	gameOverMc_,			-- ゲームオーバーMC
	gameOverMainMc_,		-- ゲームオーバーのメインMC
	gameOverCurtainMc_,		-- ゲームオーバーのカーテンMC	
	songNumberInfoMc_,		-- 残り曲数表示MC
	tamashiiGageLMc_,		-- 魂ゲージ左MC
	tamashiiGageRMc_,		-- 魂ゲージ右Mc
	tamashiiGageMc_ = {},	-- 魂ゲージ（２人分）
--	nigiyakashiMc_,			-- にぎやかしMC
	message1pMc_,			-- セリフ1ｐMC
	message2pMc_,			-- セリフ2ｐMC
	waitNotice1pMc_,		-- 「ちょっとまってね！」1pMC
	waitNotice2pMc_,		-- 「ちょっとまってね！」2pMc
	optionIconLMc_,			-- オプションアイコン左MC
	optionIconRMc_,			-- オプションアイコン右Mc
	controlGuideLMc_,		-- 操作ガイド左MC
	controlGuideRMc_,		-- 操作ガイド右Mc
	donBack1pMc_,			-- スコアボード下部の背景
	donBackMain1pMc_,		-- スコアボード下部の背景の中身
	donBack2pMc_,			-- スコアボード下部の背景
	donBackMain2pMc_,	-- スコアボード下部の背景の中身
	qrcodeImageLMc_,		-- QRコード画像左
	qrcodeImageRMc_,		-- QRコード画像右

	playerNum_ = 0,					-- プレイヤの人数
	sequence_ = 0,					-- 演出のシーケンス遷移用
	timer_ = 0,						-- 汎用タイマ
	tamashiiGageTimer_ = 0,			-- 魂ゲージ専用タイマ	
	now_count_ = 0,					-- ゲームオーバー用タイマ
	now_count_decimal_ = 0,			-- タイマの小数点以下を数える
	
	isEnableSkip_ = false,			-- 演出スキップが可能か否か
	isEffectSkip_ = false,			-- 演出スキップするか否か
	isStartGameOver_ = false,		-- ゲームオーバ演出が開始したか否か
	isCardUser_ = false,			-- カードユーザが存在するか否か
	isGetDefaultReward1p_ = false,	-- 1pプレイヤが通常ごほうびを何かしらゲットしているか否か
	isGetDefaultReward2p_ = false,	-- 2pプレイヤが通常ごほうびを何かしらゲットしているか否か
	
	isEndTamashiiGage_ = false,		-- 魂ゲージの更新が完了したか否か
	isEndFailureMotion_ = true,		-- マイドンが失敗モーションを完了したか否か
	isDisplayWaitNotice1p_ = false,	-- 「ちょっとまってね！」1pが表示されているか否か
	isDisplayWaitNotice2p_ = false,	-- 「ちょっとまってね！」2pが表示されているか否か
	isFinishSendNetwork_ = false,	-- サーバ送信が終了したか否か
	isAllPlayerFailure_ = true,		-- プレイヤ全員がノルマクリアに失敗しているか否か
	isFinishResurrection_ = false,	-- 復活アクションを完了したか否か
	
	scoreDigit_ = {0, 0},			-- スコアの桁数（２人分）
	currentTamashiiGage_ = {0, 0},	-- 現在表示されている魂ゲージのゲージ量

	--　ドンモーション実験用
	don_func_test_mode_,
	

	-- QRコード画像表示スキップのパラメータ
--	kQRCodeImageSkipInputTimerStartTime_,           -- 同時押し判定開始時間
--	kQRCodeImageSkipInputTimerDoujiAllowableTime_,  -- 同時押し判定許容時間差
--	qrcodeImageSkipInputLPlayerKey_,                -- (左プレイヤー)トリガー入力キー
--	qrcodeImageSkipInputLPlayerTimer_,              -- (左プレイヤー)トリガー入力タイマー値
--	qrcodeImageSkipInputRPlayerKey_,                -- (右プレイヤー)トリガー入力キー
--	qrcodeImageSkipInputRPlayerTimer_,              -- (右プレイヤー)トリガー入力タイマー値

	kQRCodeImageTimerInitVal_ = 50, -- QR コードタイマー初期値
	kQRCodeImageTimerSoundVoiceSlotNo_ = 5, -- QRコードのカウントダウンタイマーのボイスのスロット番号


--	イニシャライズ	
	Init = function(this)	
		Debug.PrintString("!!!ResultMain_INITIALIZE!!!")
		
		this.m_State.func_["Begin"] = function()
			-- 各種パーツ読み込み
			this.don_func_test_mode_ = 0		
			Lumen.Play()
			
			-- ムービークリップ取得
			this.m_MainMc = Lumen.GetMovieClip("main",true)
			-- 曲タイトル
			this.m_MainMc:SetText("song_name_center",g_songTitle)

			--　プレイヤ(エントリ)タイプごとに各MCを初期化
			if(g_entryType == 0) then		-- 左側１人プレイの場合
				this.m_MainMc:GotoAndStop("use_left")
				this.scoreBase1pMc_ = this.m_MainMc:GetChildMc("score_base_L",true)		-- 左側の score_base を scoreBase1p_ として初期化
				this.scoreBase1p_:Init(this.scoreBase1pMc_)
				this.don1pMc_ = this.m_MainMc:GetChildMc("don_L",true)					-- 左側のマイドンを1pマイドンとして初期化
				this.don1pMc_.don2p:SetVisible(false)
				Don.CameraReverse(0,false)												-- 1Pを通常向き（右向き）にする
--				this.nigiyakashiMc_ = this.m_MainMc:GetChildMc("nigiyakashi",true)		-- 右側のにぎやかしを取得
				this.message1pMc_ = this.m_MainMc:GetChildMc("msg_L_mc",true)			-- 左側のセリフMCを取得
				this.waitNotice1pMc_ = this.m_MainMc:GetChildMc("wait_notice_L",true)	-- 左側の「ちょっとまってね！」MCを取得
				
				
			elseif(g_entryType == 1) then	-- 右側１人プレイの場合
				this.m_MainMc:GotoAndStop("use_right")
				this.scoreBase1pMc_ = this.m_MainMc:GetChildMc("score_base_R",true)		-- 右側の score_base を scoreBase1p_ として初期化
				this.scoreBase1p_:Init(this.scoreBase1pMc_)
				this.don1pMc_ = this.m_MainMc:GetChildMc("don_R",true)					-- 右側のマイドンを1pマイドンとして初期化
				this.don1pMc_.don2p:SetVisible(true)
				Don.CameraReverse(1,true)												-- 1Pを逆向き（左向き）にする
--				this.nigiyakashiMc_ = this.m_MainMc:GetChildMc("nigiyakashi",true)		-- 左側のにぎやかしを取得
				this.message1pMc_ = this.m_MainMc:GetChildMc("msg_R_mc",true)			-- 右側のセリフMCを取得
				this.waitNotice1pMc_ = this.m_MainMc:GetChildMc("wait_notice_R",true)	-- 右側の「ちょっとまってね！」MCを取得
				
				
			else							-- それ以外（２人プレイ）の場合
				this.m_MainMc:GotoAndStop("duet")
				this.scoreBase1pMc_ = this.m_MainMc:GetChildMc("score_base_L",true)		-- 左右の score_base をそれぞれ scoreBase1p_, scoreBase2p_ として初期化
				this.scoreBase1p_:Init(this.scoreBase1pMc_)
				this.scoreBase2pMc_ = this.m_MainMc:GetChildMc("score_base_R",true)
				this.scoreBase2p_:Init(this.scoreBase2pMc_)
				this.don1pMc_ = this.m_MainMc:GetChildMc("don_L",true)					-- 左側のマイドンを1pマイドンとして初期化
				this.don2pMc_ = this.m_MainMc:GetChildMc("don_R",true)					-- 右側のマイドンを2pマイドンとして初期化				
				this.don1pMc_.don2p:SetVisible(false)
				this.don2pMc_.don1p:SetVisible(false)
				Don.CameraReverse(0,false)				-- 1Pを通常向き（右向き）にする
				Don.CameraReverse(1,true)				-- 2Pを逆向き（左向き）にする
				this.message1pMc_ = this.m_MainMc:GetChildMc("msg_L_mc",true)			-- 左側のセリフMCを取得
				this.message2pMc_ = this.m_MainMc:GetChildMc("msg_R_mc",true)			-- 右側のセリフMCを取得
				this.waitNotice1pMc_ = this.m_MainMc:GetChildMc("wait_notice_L",true)	-- 左側の「ちょっとまってね！」MCを取得
				this.waitNotice2pMc_ = this.m_MainMc:GetChildMc("wait_notice_R",true)	-- 右側の「ちょっとまってね！」MCを取得				
			end
			
			-- 別lumenの読み込み
			this.bg_:LoadMovie()				-- 背景
			Lumen.LoadMovie("lumen/000_default/gameover/GameOver","game_over_mc")								-- ゲームオーバー演出
			Lumen.LoadMovie("lumen/000_default/enso_normal/song_select/song_select_number_of_songs","song_number_info_mc")	-- 残り曲数表示（別lumen）を読み込み
			Lumen.LoadMovie("lumen/000_default/common/option","option_icon_L")									-- 演奏オプションアイコン
			Lumen.LoadMovie("lumen/000_default/common/option","option_icon_R")
			
			Lumen.LoadMovie("lumen/000_default/result/control_guide","control_guide_L")								-- 操作ガイド
			Lumen.LoadMovie("lumen/000_default/result/control_guide","control_guide_R")
			
			Lumen.LoadMovie("lumen/000_default/enso_normal/enso/tamashiigage/tamashii_gage","tamashii_gage_L")		-- 魂ゲージ	
			Lumen.LoadMovie("lumen/000_default/enso_normal/enso/tamashiigage/tamashii_gage","tamashii_gage_R")			

			Lumen.LoadMovie("lumen/000_default/result/result_board_donback","dummy_donback_l")
			Lumen.LoadMovie("lumen/000_default/result/result_board_donback","dummy_donback_r")

			Lumen.LoadMovie("lumen/000_default/result/result_reward","dummy_reward") -- ご褒美

			this.namePlateL_:LoadMovie()		-- ユーザー名
			this.namePlateR_:LoadMovie()
			this.eventTokenBg1p_:LoadMovie()			
			this.eventTokenBg2p_:LoadMovie()

			Lumen.LoadMovie("lumen/000_default/result/result_qrcode_image_l","dummy_qrcode_image_L")
			Lumen.LoadMovie("lumen/000_default/result/result_qrcode_image_r","dummy_qrcode_image_R")

			if(g_entryType == 0) then		-- 左側１人プレイの場合
				this.collaboChara1p_:CollaboCharaLoadMovieResult(g_resultStandCharaFlaFile[1])
				
			elseif(g_entryType == 1) then	-- 右側１人プレイの場合
				this.collaboChara2p_:CollaboCharaLoadMovieResult(g_resultStandCharaFlaFile[1])
			else							-- それ以外（２人プレイ）の場合
				this.collaboChara1p_:CollaboCharaLoadMovieResult(g_resultStandCharaFlaFile[1])
				this.collaboChara2p_:CollaboCharaLoadMovieResult(g_resultStandCharaFlaFile[2])
			end
			
			-- コラボキャラが存在する場合、マイドンを素どんに変更する
			this:SetCollaboDon()

			this.qrcodeImageTimer_:LoadMovie()

			-- QRコード画像表示スキップのパラメータ
			-- Common.FPS を Main のテーブルメンバーに使うと luajit.exe がとおらなくなるので初期化で設定する
--			this.kQRCodeImageSkipInputTimerStartTime_          = 0.5 * Common.FPS  -- 同時押し判定開始時間
--			this.kQRCodeImageSkipInputTimerDoujiAllowableTime_ = 0.2 * Common.FPS  -- 同時押し判定許容時間差
--			this.qrcodeImageSkipInputLPlayerKey_   = Input.PLAYER1_LEFT            -- (左プレイヤー)トリガー入力キー
--			this.qrcodeImageSkipInputLPlayerTimer_ = -1.0 * Common.FPS             -- (左プレイヤー)トリガー入力タイマー値：同時押しとみなされないくらい昔
--			this.qrcodeImageSkipInputRPlayerKey_   = Input.PLAYER2_LEFT            -- (右プレイヤー)トリガー入力キー
--			this.qrcodeImageSkipInputRPlayerTimer_ = -1.0 * Common.FPS             -- (右プレイヤー)トリガー入力タイマー値：同時押しとみなされないくらい昔

			this.m_State:SetState("Start")				
		end
		
		this.m_State.func_["Start"] = function()
			Don.SetLoopAnimation(0,"result_loop",true)	-- 1Pに"result_clear"をループ再生させる
			Don.SetLoopAnimation(1,"result_loop",true)	-- 2Pに"result_clear"をループ再生させる
			
			-- プレイヤの人数を決定
			if(g_entryType == 2) then
				this.playerNum_ = 2
			else
				this.playerNum_ = 1
			end
			
			-- カードユーザがいるか否か判断
			for idx = 1, this.playerNum_ do
				if(g_isCardUser[idx] == true) then
					this.isCardUser_ = true
				end
			end
			
			-- ノルマクリアしたプレイヤがいるか否か判断
			for idx = 1, this.playerNum_ do
				if(g_resultType[idx] ~= 0) then
					this.isAllPlayerFailure_ = false
				end
			end
			
			-- プレイヤが通常ごほうびをゲットしているか否か判断
			for rewardIndex = 0, g_getRewardNum[1] do
				if(g_rewardTokenId1p[rewardIndex] == -1) then
					this.isGetDefaultReward1p_ = true
				end
			end
			if(g_entryType == 2) then
				for rewardIndex = 0, g_getRewardNum[2] do
					if(g_rewardTokenId2p[rewardIndex] == -1) then
						this.isGetDefaultReward2p_ = true
					end
				end
			end		

			this.m_State:SetState("Loading")	
		end
		
		
		
		this.m_State.func_["Loading"] = function()
			-- 別lumenを確保
			--　ロードムービーの完了を待ってそれぞれ初期化
			if(Lumen.IsLoadMovieFinish() == true) then
						
				-- 背景MC
				this.bg_:Setup()
				this.bg_:SetPlayerInfo()
								
				-- ゲームオーバーMC
				this.gameOverMc_ = this.m_MainMc:GetChildMc("game_over_mc",true)			
				this.gameOverMainMc_ = this.gameOverMc_:GetChildMc("main",true)
				this.gameOverCurtainMc_ = this.gameOverMainMc_:GetChildMc("end_curtain_mc",true)
				
				-- 演奏オプションアイコンMC
				this.optionIconLMc_ = this.m_MainMc:GetChildMc("option_icon_L",true)
				this.optionIconRMc_ = this.m_MainMc:GetChildMc("option_icon_R",true)
				this:SetOptionIcon()
				
				-- ご褒美系設定
				-- 操作ガイドMC
				this.controlGuideLMc_ = this.m_MainMc:GetChildMc("control_guide_L",true)
				this.controlGuideRMc_ = this.m_MainMc:GetChildMc("control_guide_R",true)
				if(g_entryType == 0) then
					this.m_MainMc.dummy_reward.main:GotoAndStop("use_left")
					this.tokenBase1pMc_ = this.m_MainMc.dummy_reward.main:GetChildMc("token_base_L",true)		-- 左側の token_base を tokenBase1p_ として初期化
					this.tokenBase1p_:Init(this.tokenBase1pMc_, 1, this.rewardBase1p_, this.eventTokenBg1p_)
					this.rewardBase1pMc_ = this.m_MainMc.dummy_reward.main:GetChildMc("reward_base_L",true)	-- 左側のごほうびウィンドウMCを　rewardBase1pMc_　として初期化
					this.rewardBase1p_:Init(this.rewardBase1pMc_, 1, this.namePlateL_, this.eventTokenBg1p_, this.collaboChara1p_.existing_, g_resultDispOffDonKatsu[1])

					this.rewardBase1p_:InitControlGuide(this.controlGuideLMc_)
				elseif(g_entryType == 1) then
					this.m_MainMc.dummy_reward.main:GotoAndStop("use_right")
					this.tokenBase1pMc_ = this.m_MainMc.dummy_reward.main:GetChildMc("token_base_R",true)		-- 右側の token_base を tokenBase1p_ として初期化
					this.tokenBase1p_:Init(this.tokenBase1pMc_, 1, this.rewardBase1p_, this.eventTokenBg2p_)				
					this.rewardBase1pMc_ = this.m_MainMc.dummy_reward.main:GetChildMc("reward_base_R",true)	-- 右側のごほうびウィンドウMCを　rewardBase1pMc_　として初期化
					this.rewardBase1p_:Init(this.rewardBase1pMc_, 1, this.namePlateR_, this.eventTokenBg2p_, this.collaboChara2p_.existing_, g_resultDispOffDonKatsu[1])				

					this.rewardBase1p_:InitControlGuide(this.controlGuideRMc_)
				else
					this.m_MainMc.dummy_reward.main:GotoAndStop("duet")
					this.tokenBase1pMc_ = this.m_MainMc.dummy_reward.main:GetChildMc("token_base_L",true)		-- 左右の token_base をそれぞれ tokenBase1p_, tokenBase2p_ として初期化
					this.tokenBase1p_:Init(this.tokenBase1pMc_, 1, this.rewardBase1p_, this.eventTokenBg1p_)	
					this.tokenBase2pMc_ = this.m_MainMc.dummy_reward.main:GetChildMc("token_base_R",true)
					this.tokenBase2p_:Init(this.tokenBase2pMc_, 2, this.rewardBase2p_, this.eventTokenBg2p_)			
					this.rewardBase1pMc_ = this.m_MainMc.dummy_reward.main:GetChildMc("reward_base_L",true)	-- 左右ののごほうびウィンドウMCをそれぞれ　rewardBase1pMc_、rewardBase2pMc_　として初期化
					this.rewardBase1p_:Init(this.rewardBase1pMc_, 1, this.namePlateL_, this.eventTokenBg1p_, this.collaboChara1p_.existing_, g_resultDispOffDonKatsu[1])
					this.rewardBase2pMc_ = this.m_MainMc.dummy_reward.main:GetChildMc("reward_base_R",true)
					this.rewardBase2p_:Init(this.rewardBase2pMc_, 2, this.namePlateR_, this.eventTokenBg2p_, this.collaboChara2p_.existing_, g_resultDispOffDonKatsu[2])

					this.rewardBase1p_:InitControlGuide(this.controlGuideLMc_)
					this.rewardBase2p_:InitControlGuide(this.controlGuideRMc_)
				end
				
				-- 魂ゲージMC
				this.tamashiiGageLMc_ = this.m_MainMc:GetChildMc("tamashii_gage_L",true)
				this.tamashiiGageRMc_ = this.m_MainMc:GetChildMc("tamashii_gage_R",true)
				this:SetTamashiiGage()
				
				-- ユーザー名MC
				this.namePlateL_:Setup()
				this.namePlateL_:SetVisible(false)
				this.namePlateR_:Setup()
				this.namePlateR_:SetVisible(false)
				this:SetUserName()
		
				this.qrcodeImageLMc_  = Lumen.GetMovieClip( "dummy_qrcode_image_L", true )
				this.qrcodeImageRMc_  = Lumen.GetMovieClip( "dummy_qrcode_image_R", true )

				if ( g_isQRCodeImageValid == true ) then
					local qr_title_mc_L = this.m_MainMc:GetChildMc( "qr_title_mc_L", true )
					local qr_title_mc_R = this.m_MainMc:GetChildMc( "qr_title_mc_R", true )
					local qr_title_text_mc_L = qr_title_mc_L:GetChildMc( "qr_title_text_mc", true )
					local qr_title_text_mc_R = qr_title_mc_R:GetChildMc( "qr_title_text_mc", true )

					local guide_s_taiko_side_mc_L = this.m_MainMc:GetChildMc( "guide_s_taiko_side_mc_L", true )
					local guide_s_taiko_side_mc_R = this.m_MainMc:GetChildMc( "guide_s_taiko_side_mc_R", true )
					local guide_s_tx_mc_L = guide_s_taiko_side_mc_L:GetChildMc( "guide_s_tx_mc", true )
					local guide_s_tx_mc_R = guide_s_taiko_side_mc_R:GetChildMc( "guide_s_tx_mc", true )

					if ( g_entryType == 0 ) then
						-- 左側１人プレイの場合
						qr_title_text_mc_L:SetText( "qr_title_text",     g_qrcodeWindowTitleTextList[ 1 ] )
						qr_title_text_mc_L:SetText( "qr_title_text_sub", g_qrcodeWindowTitleTextSubList[ 1 ] )
						guide_s_tx_mc_L:SetText(    "guide_tx",          g_qrcodeWindowGuideTextList[ 1 ] )
					elseif( g_entryType == 1 ) then
						-- 右側１人プレイの場合
						qr_title_text_mc_R:SetText( "qr_title_text",     g_qrcodeWindowTitleTextList[ 2 ] )
						qr_title_text_mc_R:SetText( "qr_title_text_sub", g_qrcodeWindowTitleTextSubList[ 2 ] )
						guide_s_tx_mc_R:SetText(    "guide_tx",          g_qrcodeWindowGuideTextList[ 2 ] )
					else
						-- それ以外（２人プレイ）の場合
						qr_title_text_mc_L:SetText( "qr_title_text",     g_qrcodeWindowTitleTextList[ 1 ] )
						qr_title_text_mc_L:SetText( "qr_title_text_sub", g_qrcodeWindowTitleTextSubList[ 1 ] )
						guide_s_tx_mc_L:SetText(    "guide_tx",          g_qrcodeWindowGuideTextList[ 1 ] )
						qr_title_text_mc_R:SetText( "qr_title_text",     g_qrcodeWindowTitleTextList[ 2 ] )
						qr_title_text_mc_R:SetText( "qr_title_text_sub", g_qrcodeWindowTitleTextSubList[ 2 ] )
						guide_s_tx_mc_R:SetText(    "guide_tx",          g_qrcodeWindowGuideTextList[ 2 ] )
					end
				end

				this.qrcodeImageTimer_:Setup( 9 )
				this.qrcodeImageTimer_:SoundSetting( true, true )
				this.qrcodeImageTimer_:SetSoundVoiceSlotNo( this.kQRCodeImageTimerSoundVoiceSlotNo_ )
				this.qrcodeImageTimer_:SetVisible( false )
				this.qrcodeImageTimer_:SetShadow( false )
				this.qrcodeImageTimer_:SetCount( this.kQRCodeImageTimerInitVal_ )

				-- 残り曲数表示MC
				this.songNumberInfoMc_ = this.m_MainMc:GetChildMc("song_number_info_mc",true)					
				this.songNumberInfoMc_:SetText("main/number_of_songs","text_total_songs","attract_numberofstage")
				this.songNumberInfoMc_:SetText("main/number_of_songs","text_current_songs","attract_numberofsong")			
				
				-- イベントトークン背景MC
				if(g_entryType == 0) then
					this.eventTokenBg1p_:Setup(1)
				elseif(g_entryType == 1) then
					this.eventTokenBg2p_:Setup(1)
				else
					this.eventTokenBg1p_:Setup(1)
					this.eventTokenBg2p_:Setup(2)
				end
			
				-- スコアボードの下部背景
				this.donBack1pMc_ = this.m_MainMc:GetChildMc("dummy_donback_l",true)
				this.donBack2pMc_ = this.m_MainMc:GetChildMc("dummy_donback_r",true)
				this.donBackMain1pMc_ = this.donBack1pMc_:GetChildMc("donback",true)
				this.donBackMain2pMc_ = this.donBack2pMc_:GetChildMc("donback",true)
				this.donBackMain1pMc_:GotoAndStop("1p")
				this.donBackMain2pMc_:GotoAndStop("2p")

				this.collaboChara1p_:CollaboCharaSetup()
				this.collaboChara2p_:CollaboCharaSetup()

				this.collaboChara1p_:CollaboCharaDisplay()
				this.collaboChara2p_:CollaboCharaDisplay()

				-- C側に準備完了通知
				Common.LuaPrepareFinish()
				
				this.m_State:SetState("Fadein")
			end
		end
			

		this.m_State.func_["Fadein"] = function()
			-- フェードイン完了をｃ++から受け取ったら実行
			if(g_isFadefinish == true) then						
				-- BGMを鳴らす
				TSound:Play("bgm_result_v12a","primal_loop")	-- BGM:リザルト
				this.timer_ = 0
				this.m_State:SetState("WaitUpdateTamashiiGage")
			end
		end
		
		
		this.m_State.func_["WaitUpdateTamashiiGage"] = function()
			if(this.timer_ > 100) then
				if(g_entryType == 0) then						-- SE:魂ゲージ増加
					TSound:PlaySlot("se_common_v12a", "count_up_loop_l", 1)
				elseif(g_entryType == 1) then
					TSound:PlaySlot("se_common_v12a", "count_up_loop_r", 1)
				else
					TSound:PlaySlot("se_common_v12a", "count_up_loop_l", 1)
					TSound:PlaySlot("se_common_v12a", "count_up_loop_r", 2)
				end		
				
				this.timer_ = 0
				this.isEnableSkip_ = true		-- 演出スキップの入力受付を開始する	
				this.m_State:SetState("UpdateTamashiiGage")	
			end
		end
		
		
		
		this.m_State.func_["UpdateTamashiiGage"] = function()
			this:UpdateTamashiiGage()	-- 魂ゲージを更新

			if(this.isEffectSkip_ == true or this.isEndTamashiiGage_ == true) then
				this.timer_ = 0
				this.m_State:SetState("WaitUpdateScore")
			end
		end
		
		
		this.m_State.func_["WaitUpdateScore"] = function()
			if(this.isEffectSkip_ == true or this.timer_ > 100) then
				-- スコアの更新開始
				this.scoreBase1p_:StartScoreDisplay()
				if(g_entryType == 2) then
					this.scoreBase2p_:StartScoreDisplay()
				end
				this.timer_ = 0
				this.m_State:SetState("UpdateScore")
			end
		end
		
		
		
		this.m_State.func_["UpdateScore"] = function()
			if(this.timer_ > 500 or this.isEffectSkip_ == true) then
				this.timer_ = 0				
				this.m_State:SetState("ScoreRank")
			end
		end

		
		this.m_State.func_["ScoreRank"] = function()
			-- スコアランクを獲得しているか否かを判断⇒獲得していない場合は演出スキップ
			isSkip = false			
			if(g_entryType == 2) then
				if(g_scoreRank[1] == 0 and g_scoreRank[2] == 0) then
					isSkip = true
				end
			else
				if(g_scoreRank[1] == 0) then
					isSkip = true
				end
			end
			-- スコアランクを表示開始			
			if(isSkip == false) then
				this.scoreBase1p_:StartScoreRankDisplay()
				if(g_entryType == 2) then
					this.scoreBase2p_:StartScoreRankDisplay()
				end
			end
			if(isSkip == true or this.timer_ > 150 or this.isEffectSkip_ == true) then
				this.timer_ = 0
				this.m_State:SetState("Crown")
			end
		end
		
		
		this.m_State.func_["Crown"] = function()
			-- 王冠を獲得しているか否かを判断⇒獲得していない場合は演出スキップ
			isSkip = false
			if(g_entryType == 2) then
				if(g_crown[1] == 0 and g_crown[2] == 0) then
					isSkip = true
				end
			else
				if(g_crown[1] == 0) then
					isSkip = true
				end
			end		
			-- 王冠を表示開始
			if(isSkip == false) then
				this.scoreBase1p_:StartCrownDisplay()
				if(g_entryType == 2) then
					this.scoreBase2p_:StartCrownDisplay()
				end
			end
			if(isSkip == true or this.timer_ > 150 or this.isEffectSkip_ == true) then
				this.timer_ = 0
				this:MoveResultAction()
				this.m_State:SetState("Medal")
			end
		end
		
		
		this.m_State.func_["Medal"] = function()
			-- ローンチでは称号はカット
			this.timer_ = 0
			this.m_State:SetState("WaitEffectEnd")
		end


		
		this.m_State.func_["WaitEffectEnd"] = function()		
			if(this.timer_ > 20) then
				this:CheckDonMotion()
			end
			
			-- カードユーザーがおり、かつ「通常ごほうびをゲットしている」「遊んだのが最後の曲である」のいずれかの条件に当てはまれば実行
			if(this.isCardUser_ == true and (this.isGetDefaultReward1p_ == true or this.isGetDefaultReward2p_ == true or g_isLastSong == true)) then
				-- 一定時間経過後、セリフを非表示にしつつ、マイドンのモーションをリセット

				-- どんかつメッセージ表示後の待機時間
				local isNext = false
				if(this.collaboChara1p_.existing_ == true or this.collaboChara2p_.existing_ == true) then		-- コラボキャラ表示時
					if(this.timer_ > 500 and (Input.GetTrigger(Input.AVAILABLE_OK) == true or Input.GetTrigger(Input.AVAILABLE_CANCEL) == true)) then
						isNext = true
					elseif(this.timer_ > 3600) then
						isNext = true
					end
				else												-- コラボキャラ非表示時
					if(this.timer_ > this.kWaitEffectEndTime_) then
						isNext = true
					end
				end

				if(isNext == true) then
					if(this.isGetDefaultReward1p_ == true) then
						Don.SetLoopAnimation(0,"result_loop",true)
					end
					if(this.isGetDefaultReward2p_ == true) then
						Don.SetLoopAnimation(1,"result_loop",true)
					end
					
					if(g_isLastSong == true) then
						Don.SetLoopAnimation(0,"result_loop",true)
						Don.SetLoopAnimation(1,"result_loop",true)						
					end

					this:EraseMessage(1)
					if(g_entryType == 2) then
						this:EraseMessage(2)
					end
					this.timer_ = 0
					this.m_State:SetState("WaitStandardReward")
					Debug.PrintString("!!!this.m_State:SetState(WaitStandardReward)!!!")
				end		
			-- 上記の条件に当てはまらなければ実行
			else
				-- 一定時間待機してからリザルト画面を終了
				if(this.timer_ > this.kWaitEffectEndTime_) then
					this.timer_ = 0
					-- プレイヤ全員がノルマクリアに失敗、かつ最後の曲でない場合に実行
					if(this.isAllPlayerFailure_ == true and g_isLastSong == false) then
						-- セリフ「まだ1曲遊べるドン！」
						TSound:Play("voice_result_v12a","continue")
					end
					this.m_State:SetState("WaitNextScene")
				end
			end
		end
		
		
		
		
		this.m_State.func_["WaitStandardReward"] = function()
			-- 一定時間経過後、ごほうび付与処理へ移行
			if(this.timer_ > 50) then
				this.timer_ = 0
				this.rewardBase1p_:UpdateRewardPanel(-1, true)
				if(g_entryType == 2) then
					this.rewardBase2p_:UpdateRewardPanel(-1, true)
				end
				Debug.PrintString("!!!this.m_State:SetState(StandardReward)!!!")
				this.m_State:SetState("StandardReward")
			end
		end
		
		
		
		
		
		this.m_State.func_["StandardReward"] = function()
			-- ごほうびパネルが終了したか否かを常に問い合わせ、完了し次第次のシーケンスへ遷移
			isRewardPanelEnd = false			
			if(g_entryType == 2) then			
				if(this.rewardBase1p_:GetIsRewardPanelEnd() == true and this.rewardBase2p_:GetIsRewardPanelEnd() == true) then
					isRewardPanelEnd = true
				end
			else
				if(this.rewardBase1p_:GetIsRewardPanelEnd() == true) then
					isRewardPanelEnd = true
				end
			end
		
			if(isRewardPanelEnd == true) then
				this.timer_ = 0					
				this.tokenBase1p_:StartUpdateNormalToken()
				if(g_entryType == 2) then
					this.tokenBase2p_:StartUpdateNormalToken()
				end
				this.timer_ = 0	
				Debug.PrintString("!!!this.m_State:SetState(NormalToke)!!!")
				this.m_State:SetState("NormalToken")
			end
		end
		
		

		
		this.m_State.func_["NormalToken"] = function()
			-- 通常トークン演出が終了したか否かを常に問い合わせ、完了し次第次のシーケンスへ遷移
			local isNormalTokenEnd = false			
			if(g_entryType == 2) then
				if(this.tokenBase1p_:GetIsNormalTokenEnd() == true and this.tokenBase2p_:GetIsNormalTokenEnd() == true) then
					isNormalTokenEnd = true
				-- どちらか一方が待たされている間は「ちょっと待ってね！」表示
				elseif(this.tokenBase1p_:GetIsNormalTokenEnd() == true or this.tokenBase2p_:GetIsNormalTokenEnd() == true) then
					this:DisplayWaitNotice(this.tokenBase1p_:GetIsNormalTokenEnd())
				end
			else
				if(this.tokenBase1p_:GetIsNormalTokenEnd() == true) then
					isNormalTokenEnd = true
				end
			end
			
			if(isNormalTokenEnd == true) then
				this.timer_ = 0
				this:ResetWaitNotice()
				this.tokenBase1p_:StartUpdateEventToken()
				if(g_entryType == 2) then
					this.tokenBase2p_:StartUpdateEventToken()
				end
				this.m_State:SetState("EventToken")
			end
		end
		
		
		
		
		this.m_State.func_["EventToken"] = function()
			-- イベントトークン演出が終了したか否かを常に問い合わせ、完了し次第次のシーケンスへ遷移
			local isEventTokenEnd = false			
			if(g_entryType == 2) then
				if(this.tokenBase1p_:GetIsEventTokenEnd() == true and this.tokenBase2p_:GetIsEventTokenEnd() == true) then
					isEventTokenEnd = true					
				-- どちらか一方が待たされている間は「ちょっと待ってね！」表示
				elseif(this.tokenBase1p_:GetIsEventTokenEnd() == true or this.tokenBase2p_:GetIsEventTokenEnd() == true) then
					this:DisplayWaitNotice(this.tokenBase1p_:GetIsEventTokenEnd())
				end
			else
				if(this.tokenBase1p_:GetIsEventTokenEnd() == true) then
					isEventTokenEnd = true
				end
			end
			
			if(isEventTokenEnd == true) then
				this.timer_ = 0
				this:ResetWaitNotice()
				-- プレイヤ全員がノルマクリアに失敗、かつ最後の曲でない場合に実行
				if(this.isAllPlayerFailure_ == true and g_isLastSong == false) then
					-- セリフ「まだ1曲遊べるドン！」
					TSound:Play("voice_result_v12a","continue")
				end
				this.m_State:SetState("WaitNextScene")
			end		
		end


		
		this.m_State.func_["WaitNextScene"] = function()
			-- プレイヤ全員がノルマクリアに失敗、かつ最後の曲でない場合に実行
			if(this.timer_ > 180) then
				if(this.isAllPlayerFailure_ == true and g_isLastSong == false) then
					this:MoveDonForAllPlayerFailure()
				end
			end
		
			local isNextScene = false
			if(this.timer_ > 500 and (Input.GetTrigger(Input.AVAILABLE_OK) == true or Input.GetTrigger(Input.AVAILABLE_CANCEL) == true)) then
				isNextScene = true
			elseif(this.timer_ > 3600) then
				isNextScene = true
			end
			
			-- １人プレイ時に２Ｐのユーザー情報を１Ｐにコピーする
			if(g_entryType == 1) then
				PlayDataManager.CopySingle2PTo1P()			
			end
			
			if(isNextScene == true) then
				-- サウンド（決定）
				if(g_isLastSong == false) then
					TSound:Play("se_common_v12a","don_c")
				end

				-- QRコード画像が有効なら表示シーケンスへ、無効なら終了へ
				if ( g_isQRCodeImageValid == true ) then
					this.m_State:SetState("QRCodeImage")
				else
					g_isFinishAllEffect = true
					this.m_State:SetState("End")
				end
			end
		end
		
		
		
		this.m_State.func_["QRCodeImage"] = function()

			Debug.PrintString("ResultMain.lua : QRCodeImage")

			-- タイマー開始
			this.timer_ = 0
			this.qrcodeImageTimer_:SetVisible( true )
			this.qrcodeImageTimer_:StartCount()

			local  qrcode_goto_label = "init"

			if ( g_entryType == 0 ) then  -- 左側１人プレイの場合
				qrcode_goto_label = "use_left"
			elseif ( g_entryType == 1 ) then  -- 右側１人プレイの場合
				qrcode_goto_label = "use_right"
			elseif ( g_entryType == 2 ) then  -- ２人プレイの場合
				qrcode_goto_label = "duet"
			end

			this.m_MainMc:GotoAndPlay( qrcode_goto_label )

			this.m_State:SetState("QRCodeImage_Proc")
		end

		this.m_State.func_["QRCodeImage_Proc"] = function()
			-- タイマー０で終了へ
			this.qrcodeImageTimer_:Update()
			local qrcode_image_end = ( this.qrcodeImageTimer_:IsZero() == true )

			-- 入力からのスキップ・カウント減処理
			if ( qrcode_image_end == false ) then
				-- ドンが叩かれていたらタイマーのカウントを減らす
				local  input_l_flag = false
				local  input_r_flag = false

				if ( g_entryType ~= 0 ) then  -- 左側１人プレイでない場合は１人・２人プレイ右側プレイヤーの入力
				  input_r_flag = ( Input.GetTrigger( Input.PLAYER2_OK ) == true ) or ( Input.GetTrigger( Input.PLAYER2_CANCEL ) == true )
				end
				if ( g_entryType ~= 1 ) then  -- 右側１人プレイでない場合は１人・２人プレイ左側プレイヤーの入力
				  input_l_flag = ( Input.GetTrigger( Input.PLAYER1_OK ) == true ) or ( Input.GetTrigger( Input.PLAYER1_CANCEL ) == true )
				end
				if ( input_l_flag or input_r_flag ) then
					-- ドンが叩かれていたら Timer の decimal を 1 にする→次の Update() で 0 になる
					local timer_count = this.qrcodeImageTimer_:GetCount()
					this.qrcodeImageTimer_:SetCountAndDecimal( timer_count, 1 )
					-- 終了の音は終了してから鳴らすのでここで鳴らさない
					-- １人プレイと２人プレイで鳴らす音を分ける
					if ( 1 < timer_count ) then
						if ( g_entryType ~= 2 ) then
							-- １人プレイ時
							TSound:Play("se_common_v12a","don_c")
						else
							-- ２人プレイ時は入力があった側
							if ( input_l_flag ) then
								TSound:Play("se_common_v12a","don_l")
							end
							if ( input_r_flag ) then
								TSound:Play("se_common_v12a","don_r")
							end
						end
					end
				end
			end

--			if ( qrcode_image_end == false ) then
--				if ( g_entryType ~= 0 ) then  -- 左側１人プレイでない場合は１人・２人プレイ右側プレイヤーの処理
--					-- 太鼓のふち同時たたきで終了へ
--					local  timer_douji_max = this.qrcodeImageSkipInputRPlayerTimer_ + this.kQRCodeImageSkipInputTimerDoujiAllowableTime_;
--					-- 簡単に書くために左右カツの処理をループで処理するのやめて左右別にする
--					if ( Input.GetTrigger( Input.PLAYER2_LEFT ) == true ) then
--						-- 左カツトリガーがあったとき
--						if ( ( this.qrcodeImageSkipInputRPlayerKey_ ~= Input.PLAYER2_LEFT ) and ( this.timer_ < timer_douji_max ) ) then
--							-- 同時押し（直前が左カツでなくて許容時間内）のときは終了
--							qrcode_image_end = true
--						else
--							-- 同時押しでないときは同時押しの先に押した情報として覚えておく
--							this.qrcodeImageSkipInputRPlayerKey_   = Input.PLAYER2_LEFT
--							this.qrcodeImageSkipInputRPlayerTimer_ = this.timer_
--						end
--					end
--					if ( Input.GetTrigger( Input.PLAYER2_RIGHT ) == true ) then
--						-- 右カツトリガーがあったとき
--						if ( ( this.qrcodeImageSkipInputRPlayerKey_ ~= Input.PLAYER2_RIGHT ) and ( this.timer_ < timer_douji_max ) ) then
--							qrcode_image_end = true
--						else
--							this.qrcodeImageSkipInputRPlayerKey_   = Input.PLAYER2_RIGHT
--							this.qrcodeImageSkipInputRPlayerTimer_ = this.timer_
--						end
--					end
--				end
--				if ( g_entryType ~= 1 ) then  -- 右側１人プレイでない場合は１人・２人プレイ左側プレイヤーの処理
--					local  timer_douji_max = this.qrcodeImageSkipInputLPlayerTimer_ + this.kQRCodeImageSkipInputTimerDoujiAllowableTime_;
--					if ( Input.GetTrigger( Input.PLAYER1_LEFT ) == true ) then
--						-- Debug.PrintString("ResultMain.lua : QRCodeImage_Proc : LeftTrigger")
--						if ( ( this.qrcodeImageSkipInputLPlayerKey_ ~= Input.PLAYER1_LEFT ) and ( this.timer_ < timer_douji_max ) ) then
--							qrcode_image_end = true
--						else
--							this.qrcodeImageSkipInputLPlayerKey_   = Input.PLAYER1_LEFT
--							this.qrcodeImageSkipInputLPlayerTimer_ = this.timer_
--						end
--					end
--					if ( Input.GetTrigger( Input.PLAYER1_RIGHT ) == true ) then
--						-- Debug.PrintString("ResultMain.lua : QRCodeImage_Proc : RightTrigger")
--						if ( ( this.qrcodeImageSkipInputLPlayerKey_ ~= Input.PLAYER1_RIGHT ) and ( this.timer_ < timer_douji_max ) ) then
--							qrcode_image_end = true
--						else
--							this.qrcodeImageSkipInputLPlayerKey_   = Input.PLAYER1_RIGHT
--							this.qrcodeImageSkipInputLPlayerTimer_ = this.timer_
--						end
--					end
--				end
--			end

			if ( qrcode_image_end ) then
				-- 終了で音を鳴らす(２人プレイでも中央のみ)
				TSound:Play("se_common_v12a","don_big")

				g_isFinishAllEffect = true
				this.m_State:SetState("End")
			end
		end



		this.m_State.func_["End"] = function()
		end

-- 三浦が適当にいじったやつなのでまとめてコメントアウトしておきます
--[[
			-- 適当テスト
			if (Input.GetTrigger(Input.ALLPLAYER_DOWN) == true) then
				if(this.don_func_test_mode_ == 0) then
					Don.ChangeRandDonForPlayData(0)			-- 1P側をプレイヤーデータの中からランダム設定にする
				end
				if(this.don_func_test_mode_ == 1) then
					Don.ChangeRandDonForPlayData(1)			-- 2P側をプレイヤーデータの中からランダム設定にする
				end
				if(this.don_func_test_mode_ == 2) then
					Don.ChangeDonForPlayData(1)				-- 1P側をプレイヤーデータにあわせる
				end
				if(this.don_func_test_mode_ == 3) then
					Don.ChangeDefaultDon(0,Don.kType_Don)	-- 1Pをどんちゃん初期状態にする
					Don.ChangeDefaultDon(1,Don.kType_Katsu)	-- 2Pをかっちゃん初期状態にする
				end
				if(this.don_func_test_mode_ == 4) then
					Don.CameraReverse(0,false)				-- 1Pを通常向き（右向き？）にする
					Don.CameraReverse(1,true)				-- 2Pを逆向き（左向き？）にする
				end
				if(this.don_func_test_mode_ == 5) then
					Don.CameraReverse(0,true)				-- 1Pを逆向き（左向き？）にする
					Don.CameraReverse(1,false)				-- 2Pを通常向き（右向き？）にする
				end
				if(this.don_func_test_mode_ == 6) then
					Don.SetNonLoopAnimation(0,"miss",true)	-- 1Pに"miss"アニメをループしないで再生させる
					Don.SetNonLoopAnimation(1,1,true)		-- 2Pに1番のアニメをループしないで再生させる
				end
				if(this.don_func_test_mode_ == 7) then
					Don.SetLoopAnimation(0,"miss6",true)	-- 1Pに"miss6"アニメをループで再生させる
					Don.SetLoopAnimation(1,2,true)			-- 2Pに2番のアニメをループで再生させる
				end

				this.don_func_test_mode_ = this.don_func_test_mode_ + 1
				if(this.don_func_test_mode_ > 10) then
					this.don_func_test_mode_ = 0
				end
			end
]]

	end,
-- ここまでInit




--	毎フレーム実行
	Update = function(this)
		this.m_State:Update()			-- ステート処理	
		this.timer_ = this.timer_ + 1	--　タイマ更新		

		-- キー入力
		if (Input.GetTrigger(Input.ALLPLAYER_OK) == true) then
		elseif (Input.GetTrigger(Input.ALLPLAYER_RIGHT) == true) then
		elseif (Input.GetTrigger(Input.ALLPLAYER_LEFT) == true) then
		elseif (Input.GetTrigger(Input.ALLPLAYER_UP) == true) then
		end
		
		-- プレイヤ(エントリ)タイプごとに scoreBase を更新 ※２人プレイの場合は1p2p両方、それ以外の場合は1pのみ	
		this.scoreBase1p_:Update(this.isEffectSkip_)
		this.tokenBase1p_:Update()
		this.rewardBase1p_:Update()
		if(g_entryType == 2) then
			this.scoreBase2p_:Update(this.isEffectSkip_)
			this.tokenBase2p_:Update()
			this.rewardBase2p_:Update()
		end
		
		-- 演出スキップが可能な状態でドンが叩かれたら演出をスキップ
		if(this.isEnableSkip_ == true) then
			if (Input.GetTrigger(Input.AVAILABLE_OK) == true or Input.GetTrigger(Input.AVAILABLE_CANCEL) == true) then
				this.isEffectSkip_ = true
			end
		end	
	
		-- ゲームオーバースタートフラグが起動したら（ｃ++から起動）、ゲームオーバー演出を開始
		if(g_isGameOver == true and this.isStartGameOver_ == false) then
			this:StartGameOver()
		end
		
		--　ゲームオーバー演出が動いている間実行
		if(this.isStartGameOver_ == true) then
			this:UpdateGameOver()			
		end
	end,
-- ここまでUpdate


-- ゲームオーバー演出開始処理
	StartGameOver = function(this)
		this.gameOverMainMc_:GotoAndStop("start")
		this.gameOverCurtainMc_:GotoAndPlay("oshimai_start")
		
		-- サウンド
		TSound:StopBank("bgm_result_v12a")
		TSound:Play("se_common_v12a","curtain")
		TSound:Play("bgm_common_v12a","gameover_primal")
		TSound:Play("voice_common_v12a","gameover")
		
		-- サーバ送信
		if(this.isFinishSendNetwork_ == false) then
--			for idx = 1, this.playerNum_ do
--				NetAccess.SendResultData(idx - 1)
--			end
			-- 【！！！注意！！！】　サーバ送信の際はプレイ人数に関わらず、左側の太鼓：0、右側の太鼓：1、になります！
			if(g_entryType == 0) then
				NetAccess.SendResultData(0)
			elseif(g_entryType == 1) then
				NetAccess.SendResultData(1)
			else
				NetAccess.SendResultData(0)
				NetAccess.SendResultData(1)
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
	UpdateGameOver	= function(this)
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
			this.gameOverCurtainMc_:GotoAndPlay("copyright_start")
		elseif((this.now_count_ >= (100 + this.kWaitCopyrightTime_)) and (qr_exec_finish == true)) then
			this.gameOverCurtainMc_:GotoAndStop("end")
			g_isFinishGameOver = true	-- ゲームオーバー完了フラグを起動する
		end
	end,
-- ここまでUpdateGameOver



-- 演奏オプションアイコンをセットする
	SetOptionIcon = function(this)
		for idx = 1, this.playerNum_ do
			if(g_entryType == 0) then
				this:DisplayOptionIcon(this.optionIconLMc_, idx, false)
			elseif(g_entryType == 1) then
				this:DisplayOptionIcon(this.optionIconRMc_, idx, true)
			else
				if(idx == 1) then
					this:DisplayOptionIcon(this.optionIconLMc_, idx, false)
				else
					this:DisplayOptionIcon(this.optionIconRMc_, idx, true)
				end
			end
		end
	end,
-- ここまでSetOptionIcon



	
	-- 演奏オプションアイコンを表示する
	DisplayOptionIcon = function(this, optionIconMc, playerIndex, isRight)
		optionIconMc:GotoAndStop("menu")	
		local optionIndex = 0
		-- 倍速オプション
		if(g_optionSpeed[playerIndex] ~= 0) then
			buffStr = "option"..optionIndex
			targetMc = optionIconMc.option:GetChildMc(buffStr,true)
			if(g_optionSpeed[playerIndex] == 1) then targetMc:GotoAndStop("speedx1.1")
			elseif(g_optionSpeed[playerIndex] == 2) then targetMc:GotoAndStop("speedx1.2")
			elseif(g_optionSpeed[playerIndex] == 3) then targetMc:GotoAndStop("speedx1.3")
			elseif(g_optionSpeed[playerIndex] == 4) then targetMc:GotoAndStop("speedx1.4")
			elseif(g_optionSpeed[playerIndex] == 5) then targetMc:GotoAndStop("speedx1.5")
			elseif(g_optionSpeed[playerIndex] == 6) then targetMc:GotoAndStop("speedx1.6")
			elseif(g_optionSpeed[playerIndex] == 7) then targetMc:GotoAndStop("speedx1.7")
			elseif(g_optionSpeed[playerIndex] == 8) then targetMc:GotoAndStop("speedx1.8")
			elseif(g_optionSpeed[playerIndex] == 9) then targetMc:GotoAndStop("speedx1.9")
			elseif(g_optionSpeed[playerIndex] == 10) then targetMc:GotoAndStop("speedx2")
			elseif(g_optionSpeed[playerIndex] == 11) then targetMc:GotoAndStop("speedx2.5")
			elseif(g_optionSpeed[playerIndex] == 12) then targetMc:GotoAndStop("speedx3")
			elseif(g_optionSpeed[playerIndex] == 13) then targetMc:GotoAndStop("speedx3.5")
			elseif(g_optionSpeed[playerIndex] == 14) then targetMc:GotoAndStop("speedx4")
			end
			optionIndex = optionIndex + 1
		end
		-- どろんオプション
		if(g_optionDron[playerIndex] == true) then		
			buffStr = "option"..optionIndex
			targetMc = optionIconMc.option:GetChildMc(buffStr,true)
			targetMc:GotoAndStop("doron")
			optionIndex = optionIndex + 1
		end
		-- あべこべオプション
		if(g_optionReverse[playerIndex] == true) then		
			buffStr = "option"..optionIndex
			targetMc = optionIconMc.option:GetChildMc(buffStr,true)
			targetMc:GotoAndStop("abekobe")
			optionIndex = optionIndex + 1
		end
		-- ランダムオプション
		if(g_optionRandomlv[playerIndex] ~= 0) then		
			buffStr = "option"..optionIndex
			targetMc = optionIconMc.option:GetChildMc(buffStr,true)
			if(g_optionRandomlv[playerIndex] == 1) then targetMc:GotoAndStop("kimagure")
			elseif(g_optionRandomlv[playerIndex] == 2) then targetMc:GotoAndStop("detarame")
			end
			optionIndex = optionIndex + 1
		end	
		-- 音符表示位置調整オプション
		if(g_optionNoteDrawAdjust[playerIndex] ~= 0) then		
			buffStr = "option"..optionIndex
			targetMc = optionIconMc.option:GetChildMc(buffStr,true)
			targetMc:GotoAndStop("note_pos")
			optionIndex = optionIndex + 1
		end

		-- 表示するオプションアイコンの個数に合わせて背景画像を伸ばす
		local str = ""..optionIndex
		if(playerIndex == 1) then
			this.scoreBase1pMc_.option_icon_bg:GotoAndStop(str)
		else
			this.scoreBase2pMc_.option_icon_bg:GotoAndStop(str)
		end
	end,
	-- ここまでDisplayOptionIcon




--　魂ゲージをセットする
	SetTamashiiGage = function(this)
		text = {"easy", "normal", "normal", "hard", "hard"}
		-- プレイヤ毎に魂ゲージを初期化
		for idx = 1, this.playerNum_ do
			num = g_difficulty[idx]
			gageTypeLabel = "result_"..text[num + 1]
			if(g_entryType == 0) then
				gageTypeLabel = gageTypeLabel.."_1p"
				this.tamashiiGageLMc_:GotoAndStop(gageTypeLabel)
				this.tamashiiGageMc_[idx] = this.tamashiiGageLMc_:GetChildMc(gageTypeLabel,true)
			elseif(g_entryType == 1) then
				gageTypeLabel = gageTypeLabel.."_2p"
				this.tamashiiGageRMc_:GotoAndStop(gageTypeLabel)
				this.tamashiiGageMc_[idx] = this.tamashiiGageRMc_:GetChildMc(gageTypeLabel,true)
			else
				if(idx == 1) then
					gageTypeLabel = gageTypeLabel.."_1p"
					this.tamashiiGageLMc_:GotoAndStop(gageTypeLabel)
					this.tamashiiGageMc_[idx] = this.tamashiiGageLMc_:GetChildMc(gageTypeLabel,true)
				else
					gageTypeLabel = gageTypeLabel.."_2p"
					this.tamashiiGageRMc_:GotoAndStop(gageTypeLabel)
					this.tamashiiGageMc_[idx] = this.tamashiiGageRMc_:GetChildMc(gageTypeLabel,true)
				end
			end
			this.tamashiiGageMc_[idx].clear_text:SetText("text","clear")			
		end	
	end,
-- ここまでSetTamashiiGage




--　魂ゲージを増やす
	UpdateTamashiiGage = function(this)
		this.tamashiiGageTimer_ = this.tamashiiGageTimer_ + 1	-- 専用タイマを毎フレーム動かす
		for idx = 1, this.playerNum_ do
			-- スキップONなら増加演出なしでいきなり最終値まで飛ばす
			if(this.isEffectSkip_ == true) then
				gageNumLabel = "gage_"..g_tamashiiGage[idx]
				this.tamashiiGageMc_[idx]:GotoAndStop(gageNumLabel)
				this.currentTamashiiGage_[idx] = g_tamashiiGage[idx]
				TSound:StopSlot(idx)
				-- 魂ゲージが満タンの場合は、虹色エフェクトと炎エフェクトを起動する
				if(this.currentTamashiiGage_[idx] == this.kMaxGage_) then
					this.tamashiiGageMc_[idx].rainbow:GotoAndPlay("fever_start")
					this.tamashiiGageMc_[idx].fire:GotoAndPlay("fever_start")
				end
				
			-- スキップOFFの場合は１メモリずつ増加させる
			-- カレントメモリ数がｃ++から受け取ったゲージ数以下、かつ専用タイマがゲージ増加スピード*カレントメモリ数を超えたら実行
			elseif(this.currentTamashiiGage_[idx] < g_tamashiiGage[idx] and this.tamashiiGageTimer_ > this.kGageSpeed_ * this.currentTamashiiGage_[idx]) then
				this.currentTamashiiGage_[idx] = this.currentTamashiiGage_[idx] + 1
				gageNumLabel = "gage_"..this.currentTamashiiGage_[idx]
				this.tamashiiGageMc_[idx]:GotoAndStop(gageNumLabel)			
				-- 魂ゲージが満タンになったら、虹色エフェクトと炎エフェクトを起動する
				if(this.currentTamashiiGage_[idx] == this.kMaxGage_) then
					this.tamashiiGageMc_[idx].rainbow:GotoAndPlay("fever_start")
					this.tamashiiGageMc_[idx].fire:GotoAndPlay("fever_start")
					-- 満タン専用SEを鳴らす
					if(idx == 1 and (g_entryType == 0 or g_entryType == 2)) then
						TSound:Play("se_result_v12a","achieve_tamashii_l")
					else
						TSound:Play("se_result_v12a","achieve_tamashii_r")					
					end
				end
			end
			
			-- カレントメモリ数がｃ++から受け取ったゲージ数に到達したら、ゲージ増加中のSEを消す
			if(this.currentTamashiiGage_[idx] == g_tamashiiGage[idx]) then
				TSound:StopSlot(idx)
			end		
		end
		
		-- 更新完了を観測
		if(this.playerNum_ == 2)then
			if(this.currentTamashiiGage_[1] == g_tamashiiGage[1] and this.currentTamashiiGage_[2] == g_tamashiiGage[2]) then
				this.isEndTamashiiGage_ = true
			end
		else
			if(this.currentTamashiiGage_[1] == g_tamashiiGage[1]) then
				this.isEndTamashiiGage_ = true
			end
		end
	end,
-- ここまでUpdateTamashiiGage



-- 各種演出が終了した後に、マイドンやにぎやかし、背景等を演奏結果に合わせて動かす
	MoveResultAction = function(this)
		for idx = 1, this.playerNum_ do
			this:MoveDonResult(idx)
--			this:MoveNigiyakashi()
			this:MoveBg(idx)
			this:DisplayMessage(idx)
		end
	end,
-- ここまでMoveResultAction



-- 演奏結果に応じてマイドンを動かす
	MoveDonResult = function(this, playerIndex)
		-- ノルマクリア失敗だったら実行
		if(g_resultType[playerIndex] == 0) then
			this.isEndFailureMotion_ = false
			if(g_entryType == 0) then
				Don.SetNonLoopAnimation(0,"result_failure_p1",true)
				this.collaboChara1p_:CollaboCharaSetMotion("fail");
				TSound:Play("voice_common_v12a","sad_l")
			elseif(g_entryType == 1) then
				Don.SetNonLoopAnimation(1,"result_failure_p2",true)
				this.collaboChara2p_:CollaboCharaSetMotion("fail");
				TSound:Play("voice_common_v12a","sad_r")
			else
				if(playerIndex == 1) then
					Don.SetNonLoopAnimation(0,"result_failure_p1",true)
					this.collaboChara1p_:CollaboCharaSetMotion("fail");
					TSound:Play("voice_common_v12a","sad_l")
				else
					Don.SetNonLoopAnimation(1,"result_failure_p2",true)
					this.collaboChara2p_:CollaboCharaSetMotion("fail");
					TSound:Play("voice_common_v12a","sad_r")
				end
			end			
			
		-- ノルマクリアだったら実行
		else
--			Don.SetLoopAnimation(playerIndex - 1,"result_clear",true)
			if(g_entryType == 0) then
				Don.SetLoopAnimation(0,"result_clear",true)
				this.collaboChara1p_:CollaboCharaSetMotion("success");
			elseif(g_entryType == 1) then
				Don.SetLoopAnimation(1,"result_clear",true)
				this.collaboChara2p_:CollaboCharaSetMotion("success");
			else
				Don.SetLoopAnimation(playerIndex - 1,"result_clear",true)
				if(playerIndex == 1) then
					this.collaboChara1p_:CollaboCharaSetMotion("success");
				else
					this.collaboChara2p_:CollaboCharaSetMotion("success");
				end
			end		
			-- SEおよびエフェクトの再生
			if(g_entryType == 2)then
				if(playerIndex == 1)then
					TSound:Play("se_result_v12a","atmos_clear_l")
					TSound:Play("voice_common_v12a","glad_l")			-- VO:イエ～イ
					this.don1pMc_.sakura_effect:GotoAndPlay("start")
				else
					TSound:Play("se_result_v12a","atmos_clear_r")
					TSound:Play("voice_common_v12a","glad_r")			-- VO:イエ～イ					
					this.don2pMc_.sakura_effect:GotoAndPlay("start")
				end
			else
				TSound:Play("se_result_v12a","atmos_clear_c")
				TSound:Play("voice_common_v12a","glad_c")				-- VO:イエ～イ
				this.don1pMc_.sakura_effect:GotoAndPlay("start")
			end	
		end
	end,
--　ここまでMoveDonResult




-- にぎやかしを動かす
	MoveNigiyakashi	= function(this)
		if(g_entryType ~= 2 and g_resultType[1] ~= 0) then
--			this.nigiyakashiMc_:GotoAndStop("crear")
--			this.nigiyakashiMc_.nigiyakashi_chara_crear:GotoAndPlay("loop")
		end
	end,
-- ここまでMoveNigiyakashi





-- 背景を動かす
	MoveBg = function(this, playerIndex)
		if(g_resultType[playerIndex] ~= 0) then		-- ノルマクリアに成功していたら実行
			this.bg_:StartSuccessEffect()
		end
	end,
-- ここまでMoveBg



-- 演奏結果に応じたセリフを表示
	DisplayMessage = function(this, playerIndex)
		-- 魂ゲージの値から、どの種類のセリフを表示するか判定（魂ゲージが0～3割未満、３割～未クリア、クリア、MAXの４種類でセリフのパターンを変える）
		local messageType = ""
		if(g_tamashiiGage[playerIndex] == this.kMaxGage_) then
			messageType = "perfect"
		elseif(g_resultType[playerIndex] ~= 0) then
			messageType = "success"
		elseif(g_resultType[playerIndex] == 0 and g_tamashiiGage[playerIndex] > (this.kMaxGage_ * 0.3)) then
			messageType = "near"
		else
			messageType = "miss"
		end			
		
		-- コラボキャラがある場合は特殊台詞に変える
		local charaId = ""
		charaId = g_resultCharaStringId[playerIndex]
		
		if(charaId == "") then
			-- セリフをランダムで確定する
			rand = Common.Random(1,3)
			messageKey = "result_message_"..messageType.."_"..rand
		else
			-- ランダムの場合
			rand = Common.Random(0,g_resultMessageRate[playerIndex][4]-1)
			local messageRand = ""
			if(rand < g_resultMessageRate[playerIndex][1])then
				messageRand = "1"
			elseif(rand < g_resultMessageRate[playerIndex][2])then
				messageRand = "2"
			elseif(rand < g_resultMessageRate[playerIndex][3])then
				messageRand = "3"
			else
				messageRand = "r"
			end

			messageKey = "result_message_"..messageType.."_"..messageRand.."_"..charaId

			-- Debug.PrintString("[DisplayMessage] messageKey:" .. messageKey);
		end
		
		--　セリフを表示する
		if(playerIndex == 1) then
			this.message1pMc_:GotoAndPlay(messageType)
			this.message1pMc_.message_text:SetText("text_msg",messageKey)
		else
			this.message2pMc_:GotoAndPlay(messageType)
			this.message2pMc_.message_text:SetText("text_msg",messageKey)
		end			
	end,
-- ここまでDisplayMessage



-- 演奏結果に応じたセリフの非表示
	EraseMessage = function(this, playerIndex)
		-- 魂ゲージの値から、どの種類のセリフを表示しているか判定（魂ゲージが0～3割未満、３割～未クリア、クリア、MAXの４種類でセリフのパターンを変える）
		local messageType = ""
		if(g_tamashiiGage[playerIndex] == this.kMaxGage_) then
			messageType = "perfect"
		elseif(g_resultType[playerIndex] ~= 0) then
			messageType = "success"
		elseif(g_resultType[playerIndex] == 0 and g_tamashiiGage[playerIndex] > (this.kMaxGage_ * 0.3)) then
			messageType = "near"
		else
			messageType = "miss"
		end
		
		--　セリフをフェードアウト
		if(playerIndex == 1) then
			this.message1pMc_:GotoAndPlay(messageType.."_end")
		else
			this.message2pMc_:GotoAndPlay(messageType.."_end")
		end			
	end,
-- ここまでEraseMessage

	

-- マイドンの失敗モーションをチェックするだけの関数
	CheckDonMotion = function(this)
		for idx = 1, this.playerNum_ do
			if(this.isEndFailureMotion_ == false and g_resultType[idx] == 0) then
				if(g_entryType == 0) then
					Don.SetLoopAnimation(0, "result_failure_loop_p1", true)
				elseif(g_entryType == 1) then
					Don.SetLoopAnimation(0, "result_failure_loop_p2", true)
				else
					if(idx == 1) then
						Don.SetLoopAnimation(0, "result_failure_loop_p1", true)
					else
						Don.SetLoopAnimation(1, "result_failure_loop_p2", true)
					end
				end		
			end
		end
		
		this.isEndFailureMotion_ = true		
	end,



--　ユーザーネームをセットする
	SetUserName = function(this)	
		-- プレイヤ毎にユーザーネームを初期化
		for idx = 1, this.playerNum_ do
			if(g_entryType == 0) then
				this.namePlateL_:SetVisible(true)
				this.namePlateL_:SetPlayerInfo(1)
			elseif(g_entryType == 1) then
				this.namePlateR_:SetVisible(true)
				this.namePlateR_:SetPlayerInfo(2)
			else
				if(idx == 1) then
					this.namePlateL_:SetVisible(true)
					this.namePlateL_:SetPlayerInfo(1)
				else
					this.namePlateR_:SetVisible(true)
					this.namePlateR_:SetPlayerInfo(2)
				end
			end
		end
	end,
-- ここまでSetUserName



--　コラボキャラ表示時のどんちゃんの制御
	SetCollaboDon = function(this)
		-- コラボキャラが存在するプレイヤのどんちゃんを素どんにする
		local costume1p = PlayDataManager.GetUserClothes(0)
		local costume2p = PlayDataManager.GetUserClothes(1)

		costume1p.kigurumi = 0
		costume1p.head = 0
		costume1p.body = 0
		costume1p.face = 0
		costume1p.puchi = 0

		costume2p.kigurumi = 0
		costume2p.head = 0
		costume2p.body = 0
		costume2p.face = 0
		costume2p.puchi = 0

		if(g_entryType == 0) then		-- 左側１人プレイの場合
			if(this.collaboChara1p_.existing_ == true) then
				Don.ChangeCostume(0, costume1p)
				Don.SetNonLoopAnimation(0,"select_loop",true)	-- マイドンの初期モーションを設定

				if(g_resultDispOffDonKatsu[1] == true)then		-- どんかつ表示/非表示
					this.don1pMc_:GotoAndPlay("event_only_start")
				else
					this.don1pMc_:GotoAndPlay("event_start")
				end
			end
		elseif(g_entryType == 1) then	-- 右側１人プレイの場合
			if(this.collaboChara2p_.existing_ == true) then
				Don.ChangeCostume(1, costume2p)
				Don.SetNonLoopAnimation(1,"select_loop",true)	-- マイドンの初期モーションを設定

				if(g_resultDispOffDonKatsu[1] == true)then		-- どんかつ表示/非表示
					this.don1pMc_:GotoAndPlay("event_only_start")
				else
					this.don1pMc_:GotoAndPlay("event_start")
				end
			end
		else							-- それ以外（２人プレイ）の場合
			if(this.collaboChara1p_.existing_ == true) then
				Don.ChangeCostume(0, costume1p)
				Don.SetNonLoopAnimation(0,"select_loop",true)	-- マイドンの初期モーションを設定

				if(g_resultDispOffDonKatsu[1] == true)then		-- どんかつ表示/非表示
					this.don1pMc_:GotoAndPlay("event_only_start")
				else
					this.don1pMc_:GotoAndPlay("event_start")
				end
			end
			if(this.collaboChara2p_.existing_ == true) then
				Don.ChangeCostume(1, costume2p)
				Don.SetNonLoopAnimation(1,"select_loop",true)	-- マイドンの初期モーションを設定

				if(g_resultDispOffDonKatsu[2] == true)then		-- どんかつ表示/非表示
					this.don2pMc_:GotoAndPlay("event_only_start")
				else
					this.don2pMc_:GotoAndPlay("event_start")
				end
			end
		end
	end,



-- プレイヤ全員がノルマクリアに失敗した際の専用アクション
	MoveDonForAllPlayerFailure = function(this)
		if(this.isFinishResurrection_ == false) then
			-- 腹ばい状態のドンちゃんがいたら復活モーション
			if(this.isGetDefaultReward1p_ == false) then
				Don.SetNonLoopAnimation(0,"don_result_failure_koshibai",true)
			end
			if(this.isGetDefaultReward2p_ == false) then
				Don.SetNonLoopAnimation(1,"don_result_failure_koshibai",true)
			end
			this.isFinishResurrection_ = true
		end
	end,
--　ここまでMoveDonForAllPlayerFailure



--　「ちょっとまってね！」の表示
	DisplayWaitNotice = function(this, is1pEnd_)
		if(is1pEnd_ == true and this.isDisplayWaitNotice1p_ == false) then
			this.waitNotice1pMc_:GotoAndPlay("start")
			this.waitNotice1pMc_.text_message_instance:SetText("text_message","wait_a_minutes")
			this.isDisplayWaitNotice1p_ = true
		elseif(is1pEnd_ == false and this.isDisplayWaitNotice2p_ == false) then
			this.waitNotice2pMc_:GotoAndPlay("start")
			this.waitNotice2pMc_.text_message_instance:SetText("text_message","wait_a_minutes")
			this.isDisplayWaitNotice2p_ = true
		end
	end,
--　ここまでDisplayWaitNotice




--　「ちょっとまってね！」の非表示
	ResetWaitNotice = function(this)
		if(this.isDisplayWaitNotice1p_ == true) then
			this.waitNotice1pMc_:GotoAndPlay("end")
			this.isDisplayWaitNotice1p_ = false
		elseif(this.isDisplayWaitNotice2p_ == true) then
			this.waitNotice2pMc_:GotoAndPlay("end")
			this.isDisplayWaitNotice2p_ = false		
		end
	end,
-- ここまでResetWaitNotice



}
-- ここまでMain
