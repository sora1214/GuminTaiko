-- AI曲選択画面.全体シーケンスLua
-- Masayuki_Teraoka@al.bandainamco.jp

-- 使うクラスを読み込む
require("common.CreditSide")
require("common.NamePlate")
require("common.Sound")
require("common.State")
require("common.Timer")

require("ai_song_select.ai_song_select_derivation_main")
require("ai_song_select.ai_song_select_player_info")
require("ai_song_select.ai_song_select_wins_num_panel")
require("ai_song_select.ai_song_select_wins_num_event_panel")
require("ai_song_select.ai_song_select_tension")
require("ai_song_select.ai_song_select_ui")
require("ai_song_select.ai_song_select_bg")
require("ai_song_select.ai_song_select_song_main")
require("ai_song_select.ai_song_select_course_main")
require("ai_song_select.ai_song_select_option_main")
require("ai_song_select.ai_song_select_shop_main")
require("ai_song_select.ai_PanelData")
require("ai_song_select.ai_ChallengeCompeManager")

require("song_select.song_select_qr")

-- このクラス
AISongSelectAllMain = {
	AllState_ = State.New("AISongSelectAllMain"),
	
	-- タイマー
	timer_                               = Timer.New("timer_instance"),
	
	--　ネームプレート
	name_plate_                          = {NamePlate.New("plate_1p_instance"),NamePlate.New("plate_2p_instance")},
		
	--　総合成績パネル
	player_info_                         = PlayerInfo.New("playerinfo_instance_1"),
	
	-- 合計勝利数パネル
	wins_panel_				             = AISongSelectWinsNumPanel.New("totalwins_instance"),
	
	-- イベント合計勝利数パネル
	event_wins_panel_		             = AISongSelectEventWinsNumPanel.New("event_totalwins_instance"),

	-- AIどん調子表示
	tension_				             = AISongSelectTension.New("tension_instance"),
	
	--　背景
	songselectbg_                        = AISongSelectBg.New("bg_instance_1"),
	
	start_cnt                            = 0,						-- セットアップ完了後からのカウント
	wait_start_cnt                       = 0.1 * Common.FPS,       	-- セットアップ完了後から曲選択シーケンスに入るまでのウェイト
	
	end_cnt                              = 0,                      	-- 最後のEndシーケンスに入ってからのカウント（通常）
	wait_end_cnt                         = 0.1 * Common.FPS,       	-- 最後のEndシーケンスに入ってからC++側にLuaの終了を伝えるまでのウェイト
	
	entry_end_cnt                        = 0,                      	-- 乱入Endシーケンスに入ってからのカウント（乱入時）
	wait_entry_end_cnt                   = 1.5 * Common.FPS,       	-- 乱入Endシーケンスに入ってからEndシーケンスに入るまでのウェイト
	
	control_cnt                          = 0,                      	-- 曲選択画面に遷移してからキー入力が何も無い時にカウント
	wait_control_cnt                     = 10 * Common.FPS,        	-- 曲選択画面に遷移してから操作ガイドを大きく表示するまでのウェイト
	
	normal_motion_cnt 		             = 0,						-- 通常モーションに代わってからのカウント
	wait_normal_motion_cnt	             = 2.5 * Common.FPS,		-- 通常モーションに代わってからフルコンボモーションに代わるまでのウェイト
	
	fullcombo_motion_cnt 	             = 0,						-- フルコンボモーションに代わってからのカウント
	wait_fullcombo_motion_cnt            = 1 * Common.FPS,			-- フルコンボモーションに代わってから通常モーションに代わるまでのウェイト

	start_wait_request_cnt 	             = 0,						-- フォーカスを動かしてからのカウント
	wait_request_cnt 		             = 1.5 * Common.FPS,		-- この秒数を切り替えることで、ベストスコアのリクエストを掛けるまでの間隔が変わる

	start_debug_cnt			             = 0,						--　デバッグ用のカウント
	wait_debug_cnt			             = 10.0 * Common.FPS,		--　この数字のタイミングでQRコードのフラグON（デバッグ用
	
	start_dani_request_cnt	             = 0,						--　段位リクエスト用のカウント
	wait_dani_request_cnt	             = 0.5 * Common.FPS,		--　この数字のタイミングで段位のリクエストをON(0.5秒)
	
	kResultWaiting			             = 1,						-- 開始待機
	kResultRunning			             = 2,						-- 実行中
	kResultCanseled			             = 3,						-- キャンセルされた
	kResultDecided			             = 4,						-- 決定された
	kResultShop				             = 5, 						-- ショップ機能の開始
	
	kOpenGenreNum                        = 1,						-- 1度に何個のジャンル看板を開いたか（同時に何個も開けないので1固定)
	
	kPlayer1p				             = 1,						-- 左側プレイヤー定数
	kPlayer2p				             = 2,						-- 右側プレイヤー定数
	
	song_play_state_                     = "Wait",					--　BGMのステート
	song_play_request_                   = false,					--　BGMのリクエストをしたか

	nowPlaySongName                      = "",						--　現在再生中の曲名
	
	is_control_guide                     = false,					-- 操作ガイドが大きく表示されたか
	
	is_songTimeUp                        = false,					--　曲を選択中にタイムアウトになったか
	is_courseTimeUp                      = false,					--　難易度を選択中にタイムアウトになったか
	is_alreadyBgChange                   = false,					-- 背景の切り替えを開始したか
	is_playerCancelGuide                 = false,					-- 操作ガイドが大きくなってから、プレイヤーの入力でキャンセルされたか
	is_courseTimeUpSe                    = false,					-- 難易度選択時にタイムアウトになった時のSEを鳴らしたか
	is_touchFirstQRCode		             = false,					-- 一度でもQRコードをタッチしたか
	is_playEndEffect		             = false,					-- 難易度決定時の3Dどんのエフェクト再生をしたか
	is_playDerivation	 	             = false,					-- 導出演出を開始したか
	is_AIDonMotionFullCombo	             = false,					-- AIどんがフルコンボモーションかどうか
	is_allSetupOk			             = false,					-- このシーンでのセットアップが完了したか
	backPanelData         	             = 0,						-- 戻る看板のデータを入れる変数
	is_bestCrownScoreChangeRequestOniUra = false,					-- 王冠ベストスコア取得のリクエストをおに裏に変更するか
	is_bestSectionScoreRequest			 = false,					-- 選択した楽曲・難易度のリクエストをしたか
	
	requestDaniIndex					 = 16,						-- リクエストを掛ける段位のインデックス

	Init = function(this)
		Debug.PrintString("[AISongSelectAllMain] Init_Start")
		
		-- 各クラスの作成及びLumenファイルの読み込み
		this.AllState_.func_["Begin"] = function()
			-- 各種パーツ読み込み
			Debug.PrintString("[AISongSelectAllMain] SequenceStart_Begin")

			songselectui_         = AISongSelectUi.New("song_of_number_instance","control_guide_instance")
			songselectsong_       = AISongSelectSongMain.New(0)
			songselectcourse_     = AISongSelectCourseMain.New(1)
			songselectshop_       = AISongSelectShopMain.New()
			songselectderivation_ = AISongSelectDerivationMain.New("derivation_instance")
			
			songselectcourse_    :LoadMovieCourseMain()
			songselectshop_      :LoadMovieShopMain()
			songselectderivation_:LoadMovieDerivationMain()
			
			this.timer_      :LoadMovie()
			this.player_info_:LoadMovie()
			
			this.name_plate_[this.kPlayer1p] :LoadMovie()
			this.name_plate_[this.kPlayer2p] :LoadMovie()
			
			this.wins_panel_        :LoadMovieTotalWinsPanel()
			this.event_wins_panel_  :LoadMovieEventTotalWinsPanel()

			this.tension_     :LoadMovieTension()
			this.songselectbg_:LoadMovieBg()
			songselectui_     :LoadMovieUi()

			-- ＱＲ読み込み
			SongSelectQR:Init()

			this.AllState_:SetState("Loading")
			Debug.PrintString("[AISongSelectAllMain] SequenceEnd_Begin")
		end
		
		-- 総合成績パネルのロード待ち
		this.AllState_.func_["Loading"] = function()
		
			-- プレイヤー情報
			if(this.player_info_:Loading() == false) then
				return
			end
			
			this.AllState_:SetState("SetUp")

		end
		
		--　初期値のセットアップ
		this.AllState_.func_["SetUp"] = function()
			if (Lumen.IsLoadMovieFinish() == true) then
				
				-- タイマーの準備
				this.timer_:Setup(9)
				this.timer_:SoundSetting(true, true)
				this.timer_:SetVisible(true)
				this.timer_:SetShadow(false)
				this.timer_:SetCount(100)
				
				this.timer_:StartCount()
				
				-- ユーザーデータ一度取得(エントリーサイドに合わせて取得するデータを切り替える)
				if (is_joinPlayer[1] == true) then
					play_data_                  = PlayDataManager.GetEntryPlayData(0)
					user_setting_data_          = PlayDataManager.GetEnsoModeSetting(0)
					user_setting_Original_data_ = PlayDataManager.GetOriginalEnsoModeSetting(0)
				else
					play_data_                  = PlayDataManager.GetEntryPlayData(1)
					user_setting_data_          = PlayDataManager.GetEnsoModeSetting(1)
					user_setting_Original_data_ = PlayDataManager.GetOriginalEnsoModeSetting(1)
				end
				
				-- 季節のIDをここで代入
				this:SetUpSeasonId()
				
				-- プレイヤー情報（カード）
				this:InitPlayerInfo()
				
				-- 合計勝利数パネル
				this.wins_panel_:SetupTotalWinsPanel()
				
				-- イベント合計勝利数パネル
				this.event_wins_panel_:SetupEventTotalWinsPanel()

				-- AIどん調子
				this.tension_:SetupTension()
				
				-- 背景
				this.songselectbg_:SetupBg()
				
				-- その他UI
				songselectui_:SetupUi()
				songselectui_:InitNumberOfSongs()
				songselectui_:SetTextControlGuide()				
				
				-- 各画面のイニシャライズ（曲・難易度・ショップ・ロード前）
				songselectsong_:Init()
				songselectcourse_:Init()
				songselectshop_:Init()
				songselectderivation_:SetupDerivation()
				
				--　3Dドンのイニシャライズ
				this:InitDon3D()
				
				-- 3DAIドンのイニシャライズ
				this:InitAIDon3D()
				
				--　ネームプレートのイニシャライズ
				this:InitNamePlate()
				
				-- 大会・挑戦状アイコン用マネージャーのセットアップ
				AIChallengeCompeManager:SetUp()
				
				-- ＱＲ読み込みウィンドウのセットアップを行う
				SongSelectQR:Setup()

				-- オプションの設定
				songselectcourse_:SetUpSongSelectOption()
				
				is_freePlay = PlayDataManager.IsFreePlay()
				
				-- チュートリアルを見ているかどうか(チュートリアルはカード・コイン共通)
				is_aiPlayerTutorial = play_data_.user_data.disp_info.is_aitutorial_play
				
				--　以下カードユーザー限定の事項
				if (play_data_.user_type == UserType.kCard) then
					-- ユーザー情報
					is_CardPlayer = true
					this.player_info_:SetVisible(true)
					
					-- 左太鼓で入った時
					if (is_joinPlayer[1] == true) then
						this.player_info_:SetPlayerInfo(this.kPlayer1p,-1)

					-- 右太鼓で入った時
					else
						this.player_info_:SetPlayerInfo(this.kPlayer2p,-1)
					end

					-- プレイヤーが設定した難易度を取得
					cardPlayerSelectedCourse = play_data_.user_data.totalRecordInfo.disp_crown_level

					-- プレイヤーが設定したオプションを設定
					songselectcourse_:SetOptionLastDiff()						
				end
				
				-- おにを解放しているかどうかのフラグの上書き
				playerOpenOni = play_data_.user_data.disp_info.is_oni_open
				
				if (playerOpenOni == true) then
					playerOpenLevel = kPlayerOpenOni
				end
				
				this.is_allSetupOk = true
				
				this:RequestDaniBestScore()

				-- C側に準備完了通知
				Common.LuaPrepareFinish()

				-- オプションの初期設定
				songselectcourse_:InitOptionIcon()
				
				this.AllState_:SetState("StartWait")
				Debug.PrintString("[AISongSelectAllMain] SequenceEnd_Loading")

			end
		end
		
		--　曲選択シーケンス前のウェイト
		this.AllState_.func_["StartWait"] = function()
		
			Debug.PrintString("[AISongSelectAllMain] SequenceStart_StartWait")
			
			if(this:waitCnt() == true) then
				
				backPanelNum   = 0
				this.start_cnt = 0
				this:RemoveFolder()

				songselectui_:StartControlGuide()

				this:CreateGenreData()

				-- ＱＲ読み込み表示開始
				SongSelectQR:TouchWaitStart(SceneType.kAISelect)

				this.AllState_:SetState("SongSelectMain")
				
				Debug.PrintString("[AISongSelectAllMain] SequenceEnd_StartWait")
			end
		end

		--　曲選択シーケンス
		this.AllState_.func_["SongSelectMain"] = function()
			--Debug.PrintString("[AISongSelectAllMain] SequenceStart_SongSelectMain")
			
			--　タイムアウト時
			if(this.timer_:IsZero() == true and songselectsong_.is_timeUpEnable == true and songselectsong_.mc_Kanban:IsPlay() == false) then
				Debug.PrintString("[SongSelectMain] TimeUp")
				-- タイマー再設定
				this.timer_:SetCount(30)

				this.is_songTimeUp = true
				
				-- 操作ガイドが大きい場合デフォルトに戻す
				if(songselectsong_:GetControlGuideFlag() == true) then songselectui_:StartDefaultControlGuide() end
				songselectsong_:SetControlGuideFlag(false)
				
				-- 入力を切る
				songselectsong_:SetInputEnable(false)
				
				-- タイムアップシーケンスの準備
				songselectsong_:TimeUpBegin()
				-- ＳＥ「大どん（中央）」
				TSound:Play("se_common_v12a","don_big")
			end
			
			-- QRコードで曲指定されたらステートを切り替える
			SongSelectQR:ChangeState(this.timer_)
--[[
			-- QRコードをタッチしたらステートを切り替える
			if (is_touchQRCode == true and this.timer_:IsZero() == false and songselectsong_:GetMoveFlag() == false and songselectsong_.is_setUpAllOk == true) then
				Debug.PrintString("[SongSelectMain] QRCode")
				
				this.is_touchFirstQRCode = true
				is_touchQRCode           = false
				
				-- 操作ガイドが大きい場合デフォルトに戻す
				if(songselectsong_:GetControlGuideFlag() == true) then songselectui_:StartDefaultControlGuide() end
				songselectsong_:SetControlGuideFlag(false)
				
				-- 入力を切る
				songselectsong_:SetInputEnable(false)
				
				-- QRコードシーケンスの準備
				songselectsong_:QRCodeSelectBegin(QRSelectSongUniqueId)
				
			end
]]

			--　フォルダを開いたとき
			if (songselectsong_:GetOpenFolder() == true and SongSelectQR.is_QRCodeTouching == false) then
--			if (songselectsong_:GetOpenFolder() == true) then
				Debug.PrintString("OpenGenreFolder-----------------------------------")
				songselectsong_:SetOpenFolder(false)
				
				this:OpenGenreFolder()
				songselectsong_:SetCurrentSongIndex(songselectsong_:GetFirstSongIndex(false))
				songselectsong_:UpdatePanelNum(selectedSongNum, this.kOpenGenreNum)
				
				genreSelectFlag   = false	-- C++側へジャンルフォルダを開き済みなのを通知
				reGenreSelectFlag = true	-- C++側へジャンルフォルダを開いたことを通知
				
				songselectsong_:OpenGenreFolder()
				
				if (this.is_songTimeUp == true and songselectsong_:GetTimeUpOpenAnimataionEnd() == true) then 
					songselectsong_:TimeUpSequence() 
				end
				
			end
			
			songselectsong_:Update()
			this:ControlGuideSongMain()
			this:UpdateBestScore()
			this:AIBestScoreMain()
			this:UpdateSectionCrown()
			this:UpdataPlayerInfo()
			
			-- 段位のベストスコアをリクエスト
			if(this:DaniRequestCount() == true) then
				this:RequestDaniBestScore()
			end
			
			-- 次の曲を再生するときは今の曲を止める
			if (songselectsong_:GetPlaySoundFlag() == true) then
				this:StopSound()
			end
			
			--　フォーカスしたパネルが開いたら曲を流す
			if (songselectsong_:GetFocusOpenPanel() == true) then
				this:PlaySound()
			end
			
			--　フォルダ以外にフォーカスして選択したとき（主に曲）
			if (songselectsong_:GetResult() == this.kResultDecided) then
				songselectsong_.mc_main:GotoAndPlay("change_courseselect")
				
				songselectsong_:SetResultType(this.kResultRunning)
				songselectsong_:ReStartSongSelect()
				songselectui_:SetVisibleControlGuide(false)
				
				--　タイムアウトで曲が勝手に決まった時
				if (this.is_songTimeUp == true) then 
					this.timer_:StartCount()
					songselectcourse_:SetTimeUpFlag(true) 
				
				-- 曲を決めた時に30秒未満のタイマーなら30秒まで増やす
				elseif (this.timer_:GetCount() < 30) then
					this.timer_:SetCount(30)
				end

				this:PlaySound()

				-- 難易度選択を選んだらＱＲ止める
				SongSelectQR:TouchWaitFinish()

				this.AllState_:SetState("CourseSelectMain")
				
				--　あそびかた説明で決定したとき
				if (is_SelectTutorial == true) then
					this.AllState_:SetState("End")
				end

			--　とじるを選んだ時
			elseif (songselectsong_:GetResult() == this.kResultCanseled) then
				
				songselectsong_:SetResultType(this.kResultRunning)
				this:CloseGenreFolder()
				songselectsong_:UpdatePanelNum(selectedSongNum, 0)
				reGenreSelectFlag = true
				songselectsong_:CloseGenreFolder()
			
			--　決定した楽曲が購入対象の時
			elseif (songselectsong_:GetResult() == this.kResultShop) then
				
				songselectsong_:SetShopBackFlag(false)
				songselectsong_:SetResultType(this.kResultRunning)
				songselectsong_:BackShopSongselect()
				songselectshop_.is_start = true

				-- 難易度選択を選んだらＱＲ止める
				SongSelectQR:TouchWaitFinish()

				this.AllState_:SetState("ShopMain")

			end

			-- メインシーケンスの時かつフォルダを開いてない時
			if (songselectsong_.State_.state_ == "Main" and songselectsong_:GetOpenFolder() == false) then	
				SongSelectQR:UpdateQR(this,"SongSelectMain")
			end

		end
		
		--　難易度選択シーケンス
		this.AllState_.func_["CourseSelectMain"] = function()
			
			--　タイムアウトの時
			if(this.timer_:IsZero() == true) then
				
				-- オプションを開いている場合
				if(songselectcourse_:GetIsOption() == true)then
					songselectcourse_:TimeUpOptionSequence()
					this.timer_:SetCount(10)
					this.timer_:StartCount()
					TSound:Play("se_common_v12a","don_big") 
					
				-- オプションを開いていない場合
				else
					if (this.is_courseTimeUp == false) then songselectcourse_:TimeUpSequence() end
					this.is_courseTimeUp = true
					
					songselectcourse_:SetTimeUpFlag(true) 
					-- ＳＥ「大どん（中央）」
					if (this.is_courseTimeUpSe == false) then TSound:Play("se_common_v12a","don_big") end
					this.is_courseTimeUpSe = true
				end
				
			end

			songselectcourse_:Update()

			-- ベストスコアと総合成績を更新
			this:UpdateBestScore()
			this:UpdataPlayerInfo()
			this:SetBestSectionScore()
			
			this:AIBestScoreForCourseMain()
			this:UpdateSectionCrown()
			
			-- 段位のベストスコアをリクエスト
			if(this:DaniRequestCount() == true) then
				this:RequestDaniBestScore()
			end
			
			--　難易度が決まったら直ぐにタイマーを止める
			if (songselectcourse_.is_timerStop == true) then this.timer_:StopCount() end
			
			--　難易度が確定したら次のシーンをセットしDerivationMainシーケンスへ
			if (songselectcourse_:GetResult() == this.kResultDecided) then
	
				nextMode = SceneType.kEnsoGame
				this.AllState_:SetState("DerivationMain")
			
			--　難易度シーケンスで戻るを選んだ時
			elseif(songselectcourse_:GetResult() == this.kResultCanseled) then
				
				-- キャンセル時にタイマー30以下ならタイマー再設定
				if(this.timer_:IsZero() == true or this.timer_:GetCount() <= 30) then
					this.timer_:SetCount(30)
					this.timer_:StartCount()
					this.is_courseTimeUp = false
					songselectcourse_:SetTimeUpFlag(true)
				end
				
				songselectsong_.mc_main:GotoAndPlay("change_songselect")
				songselectcourse_:SetResultType(this.kResultRunning)
				songselectcourse_:ReStartCourseSelect()
				
				songselectsong_:SetCourseBackFlag(true)
				songselectsong_:SetSongDataAll()
				songselectsong_.mc_Kanban:GotoAndStop("wait")
				songselectsong_:SetSongIcon()
				songselectui_:SetVisibleControlGuide(true)
				
				-- ＱＲ読み込み表示開始
				SongSelectQR:TouchWaitStart(SceneType.kAISelect)

				this.AllState_:SetState("SongSelectMain")

			end
		end
		
		--　楽曲購入シーケンス
		this.AllState_.func_["ShopMain"] = function()
			--Debug.PrintString("[AISongSelectAllMain] ShopMain")
			
			--　タイムアウト時
			if(this.timer_:IsZero() == true) then
				Debug.PrintString("[ShopMain] TimeUp")
				
				songselectshop_:TimeUpSequence()				
			end
			
			--　ネットワーク通信中はタイマーを止める
			if (songselectshop_:GetNetWorkState() == songselectshop_.knetworkStart) then
				this.timer_:StopCount()
			end
			
			songselectshop_:Update()
			
			--　購入しなかったとき
			if (songselectshop_:GetResult() == this.kResultCanseled) then
				
				this.timer_:StartCount()
				songselectsong_:SetShopBackFlag(true)
				songselectsong_:SetTokenInformation()
				songselectshop_:SetResultType(this.kResultWaiting)
				songselectshop_:ReStartShop()
				this:UpdatePlayData()

				-- ＱＲ読み込み表示開始
				SongSelectQR:TouchWaitStart(SceneType.kAISelect)

				this.AllState_:SetState("SongSelectMain")
			
			--　購入したとき
			elseif (songselectshop_:GetResult() == this.kResultDecided) then
				
				reBuyFlag = true
				
				-- 左太鼓で入った時
				if (is_joinPlayer[1] == true) then
					this.player_info_:UpdateTokenInfo(this.kPlayer1p)
				-- 右太鼓で入った時
				else
					this.player_info_:UpdateTokenInfo(this.kPlayer2p)
				end

				this.timer_:StartCount()
				songselectsong_:SetShopBackFlag(true)
				songselectsong_:SetTokenInformation()
				songselectshop_:SetResultType(this.kResultWaiting)
				songselectshop_:ReStartShop()
				this:UpdatePlayData()

				-- ＱＲ読み込み表示開始
				SongSelectQR:TouchWaitStart(SceneType.kAISelect)

				this.AllState_:SetState("SongSelectMain")
			end
			
		end
		
		-- 導出画面
		this.AllState_.func_["DerivationMain"] = function()
			Debug.PrintString("[DaniSelectAllMain] SequenceStart_DerivationMain")
			
			this:CheckSelectedCourse()
			
			if (songselectderivation_.mc_main.main.current_frame == 43) then
				TSound:Play("se_senkyoku_v12a","ai_loading_running")
			
			elseif (songselectderivation_.mc_main.main.current_frame == 77) then
				TSound:Play("se_senkyoku_v12a","ai_loading_finish")
			end

			if (this.is_playDerivation == false) then
				songselectderivation_:PlayDerivation()
				this:SetEndAnimataion3D()
				this.is_playDerivation = true
			end
			
			if (songselectderivation_:Is_EndAnimation() == true) then
				this.AllState_:SetState("End")
			end

		end

		--　大きい操作ガイドの表示シーケンス
		this.AllState_.func_["InputWait"] = function()
			
			SongSelectQR:UpdateQR(this,"InputWait")

			if(this.timer_:IsZero() == true) then
				Debug.PrintString("[InputWait] TimeUp")
				this.AllState_:SetState("SongSelectMain")
				return
			end
			
			if (is_touchQRCode == true and this.timer_:IsZero() == false and songselectsong_:GetMoveFlag() == false) then
				this.AllState_:SetState("SongSelectMain")
				return
			end
			
			--Debug.PrintString("[AISongSelectAllMain] InputWait")
			this:ControlGuideSongMain()
			
			--　プレイヤーが入力して操作ガイドをキャンセルしたとき
			if(this.is_playerCancelGuide == true) then
				this.AllState_:SetState("SongSelectMain")
				Debug.PrintString("[AISongSelectAllMain] SequenceEnd_InputWait")
			end
		end

		--　QRコード使用中のステート
		this.AllState_.func_["QRState"] = function()
			Debug.PrintString("[SongSelectAllMain] QRState")
			SongSelectQR:UpdateQR(this,"")
		end

		--　全体シーケンスのEnd
		this.AllState_.func_["End"] = function()
			Debug.PrintString("[AISongSelectAllMain] End")
			
			SongSelectQR:TouchWaitFinish()

			--　指定のフレームをカウント且つSEが止まっていれば終了させる
			if (this:WaitEndCnt() == true and TSound:IsPlayingBank("se_common_v12a") == false) then
				Common.LuaFinish()
			else
				TSound:StopBank("se_common_v12a")
				return
			end
		end
		Debug.PrintString("[AISongSelectAllMain] Init_End")
	end,
	
-- ここまでSongSelectAllInit
	
	-- デバッグ用のカウント ※最後に必ず消すこと
	DebugCount = function(this)
	
		this.start_debug_cnt = this.start_debug_cnt +1
		
		if (this.start_debug_cnt >= this.wait_debug_cnt) then
			this.start_debug_cnt = 0
			return true
		else return false
		end
	end,

	--　曲選択シーケンス前のカウント
	waitCnt = function(this)
		Debug.PrintString("[AISongSelectAllMain] waitCnt")

		this.start_cnt = this.start_cnt + 1
		
		if (this.start_cnt >= this.wait_start_cnt) then
			this.start_cnt = 0
			return true
		else return false
		end
	end,
	
	--　C++側にLuaの終了を伝えるまでのカウント
	WaitEndCnt = function(this)
		Debug.PrintString("[AISongSelectAllMain] WaitEndCnt")

		this.end_cnt = this.end_cnt + 1
		
		if (this.end_cnt >= this.wait_end_cnt) then
			this.end_cnt = 0
			return true
		else return false
		end
	end,
	
	--　乱入時のSEが鳴りやむまでのカウント
	EntryWaitEnd = function(this)
		Debug.PrintString("[AISongSelectAllMain] EntryWaitEnd")

		this.entry_end_cnt = this.entry_end_cnt + 1
		
		if (this.entry_end_cnt >= this.wait_entry_end_cnt) then
			this.entry_end_cnt = 0
			return true
		else return false
		end
	end,
	
	-- AIドンの通常モーション切り替え用カウント
	CntNormalMotion = function(this)
	
		Debug.PrintString("[AISongSelectAllMain] CntNormalMotion")

		this.normal_motion_cnt = this.normal_motion_cnt + 1
		
		if (this.normal_motion_cnt >= this.wait_normal_motion_cnt) then
			this.normal_motion_cnt = 0
			return true
		else return false
		end
	end,
	
	-- AIドンのフルコンボモーション切り替え用カウント
	CntFullComboMotion = function(this)
	
		Debug.PrintString("[AISongSelectAllMain] CntFullComboMotion")

		this.fullcombo_motion_cnt = this.fullcombo_motion_cnt + 1
		
		if (this.fullcombo_motion_cnt >= this.wait_fullcombo_motion_cnt) then
			this.fullcombo_motion_cnt = 0
			return true
		else return false
		end
	end,
	
	-- 操作ガイドのフレームカウント
	ControlGuideCount = function(this)
		--Debug.PrintString("[AISongSelectAllMain] ControlGuideCount")
		this.start_cnt = this.start_cnt + 1
		
		if (this.start_cnt >= this.wait_control_cnt) then
			this.start_cnt = 0
			return true
			
		else return false
		end
	end,
	
	-- ベストスコアのリクエストを掛けるまでのカウント
	waitRequestCnt = function(this)
		this.start_wait_request_cnt = this.start_wait_request_cnt +1
		
		if (this.start_wait_request_cnt >= this.wait_request_cnt) then
			this.start_wait_request_cnt = 0
			return true
		else return false
		end
	end,
	
	-- 段位スコアのリクエスト用カウント
	DaniRequestCount = function(this)
	
		this.start_dani_request_cnt = this.start_dani_request_cnt +1
		
		if (this.start_dani_request_cnt >= this.wait_dani_request_cnt) then
			this.start_dani_request_cnt = 0
			return true
		else return false
		end
	end,

	-- 3Dドンのイニシャライズ
	InitDon3D = function(this)
	
		Debug.PrintString("InitDon3D")
		
		this.don1p_ = Lumen.GetMovieClip("don_1p",true)

		Don.SetLoopAnimation(0,"result_clear_loop",true)
		
		Don.ChangeDonForPlayData(0,Don.kType_Don)
		Don.CameraReverse(0,false)
		this.don1p_:SetVisible(true)
		
	end,
	
	-- 3DAIドンのイニシャライズ
	InitAIDon3D = function(this)
		
		this.don2p_ = Lumen.GetMovieClip("don_2p",true)
		
		if (this.tension_:GetAITension() == AICondition.kWorst) then
			Don.SetLoopAnimation(1,"result_percious_loop",true)
		elseif (this.tension_:GetAITension() == AICondition.kBad) then
			Don.SetLoopAnimation(1,"result_failure_loop",true)
		elseif (this.tension_:GetAITension() == AICondition.kNormal) then
			Don.SetLoopAnimation(1,"result_clear_loop",true)
		elseif (this.tension_:GetAITension() == AICondition.kGood) then
			Don.SetLoopAnimation(1,"balloon_loop",true)
		else
			Don.SetLoopAnimation(1,"select_loop",true)
		end
		
		-- AIドンの表示の部分をここに記述予定
		Don.ChangeDefaultDon(1,Don.kType_AI)
		this.don2p_:SetVisible(true)
		Don.CameraReverse(1,true)

	end,
	
	-- 3DドンとAIドンのロード画面遷移時のアニメーション
	SetEndAnimataion3D = function(this)
		Don.SetLoopAnimation(0,"balloon_loop",true)
		Don.SetLoopAnimation(1,"balloon_loop",true)
	end,
	
	-- 3Dドンのモーションを切り替える
	ChangeAIDonMotion = function(this)
	
		if (this.tension_:GetAITension() == AICondition.kBest and songselectcourse_:GetIsSelectEnd() == false) then
			
			if (this.is_AIDonMotionFullCombo == false) then
			
				if (this:CntNormalMotion() == true) then
					Don.SetLoopAnimation(1,"full_combo",true)
					this.is_AIDonMotionFullCombo = true
				end
			else
				if (this:CntFullComboMotion() == true) then
					Don.SetLoopAnimation(1,"select_loop",true)
					this.is_AIDonMotionFullCombo = false
				end
			end
		end
	
	end,

	-- ネームプレートのイニシャライズ
	InitNamePlate = function(this)
		Debug.PrintString("[AISongSelectAllMain] InitNamePlate")
		
		-- ネームプレートの準備
		this.name_plate_[this.kPlayer1p]:Setup()
		this.name_plate_[this.kPlayer2p]:Setup()
		
		-- AIドンのセットアップ
		this.name_plate_[this.kPlayer2p]:SetAIDon()
		
		if (is_joinPlayer[1] == true) then
			this.name_plate_[this.kPlayer1p]:SetPlayerInfoAI(this.kPlayer1p)
		else
			this.name_plate_[this.kPlayer1p]:SetPlayerInfoAI(this.kPlayer2p)
		end
	end,
	
	-- 総合成績パネルのイニシャライズ
	InitPlayerInfo = function(this)
		Debug.PrintString("InitPlayerInfo")
		
		this.player_info_:Setup()
		this.player_info_:SetVisible(false)
	end,
	
	-- ジャンルフォルダを開いた時
	OpenGenreFolder = function(this)
		Debug.PrintString("OpenGenreFolder")
		
		backPanelNum   = 0
		this.start_cnt = 0

		this:CreateGenreData()
		this:CreateSongData()
		this:CreateUserPlayRecordData()
		
		this:InsertBackPanel()
		this:InsertBackPanelSingle()
		this:InsertSongPanel()
	end,
	
	-- ジャンルフォルダを閉じた時
	CloseGenreFolder = function(this)
		Debug.PrintString("CloseGenreFolder")

		backPanelNum    = 0
		this.start_cnt  = 0
		selectedSongNum = 0

		InitializeGenreData()
		InitializeSongData()
		
		this:CreateGenreData()
	end,

	-- 全楽曲情報を作成
	CreateSongData = function(this)
		Debug.PrintString("CreateSongData")

		songData = {}
		
		--　開いたフォルダの曲の数だけパネルクラスを作成
		for i = 1, selectedSongNum do
			
			songData[i] = AIPanelData.New() 
			
			songData[i]:SetMusicInfoData(i)
			songData[i]:SetMusicAttributeData(i)
			
		end
	end,
	
	-- プレイヤーの記録情報を作成
	CreateUserPlayRecordData = function(this)
		Debug.PrintString("CreateUserPlayRecordData")
		
		--　王冠・スコアランクなどの記録を取得する
		for i = 1, selectedSongNum do
			songData[i]:MusicRecordInfoData(i)
		end
	end,
	
	-- 全ジャンル情報を作成
	CreateGenreData = function(this)
		Debug.PrintString("CreateGenreData")

		genreData = {}
		
		--　ジャンルの数だけパネルクラスを作成
		for i = 1, #tbl_genreName do
		
			genreData[i] = AIPanelData.New() 
			
			genreData[i]:SetGenreInfoData(i)
		end
	end,
	
	-- ベストスコア表示を更新
	UpdateBestScore = function(this)
		--Debug.PrintString("[AISongSelectAllMain] UpdateBestScore")
		
		if ((is_CardPlayer == true) and data ~= nil) then
			if (data.song_uniqueId ~= -1 and data.song_uniqueId < 99999) then 
			
				-- 左太鼓で入った時
				if (is_joinPlayer[1] == true) then
					this.player_info_:UpdateBestScoreInfo(this.kPlayer1p, data.song_uniqueId)
				-- 右太鼓で入った時
				else
					this.player_info_:UpdateBestScoreInfo(this.kPlayer2p, data.song_uniqueId)		
				end
			else
				-- 左太鼓で入った時
				if (is_joinPlayer[1] == true) then
					this.player_info_:UpdateBestScoreInfo(this.kPlayer1p, -1)
				-- 右太鼓で入った時
				else
					this.player_info_:UpdateBestScoreInfo(this.kPlayer2p, -1)
				end
			end
		end
	end,
		
	-- 段位のベストスコアを取得
	RequestDaniBestScore = function(this)
		
		if (is_CardPlayer == false or this.requestDaniIndex >= 20) then
			return
		end
		
		local clear_level = play_data_.user_data.daniRecordInfo.normal_rank[this.requestDaniIndex]
		local disable_request = false
		
		if (clear_level > DaniClearRank.kNoPlay) then
			if (is_joinPlayer[1] == true) then
				NetAccess.GetDaniScore(0, this.requestDaniIndex)
			else
				NetAccess.GetDaniScore(1, this.requestDaniIndex)
			end
		else
			-- 該当の段位を遊んでないなら値を増やすフラグを建てる
			disable_request = true
		end
		
		globalDaniRequestIndex = this.requestDaniIndex
	
		if (AddDaniScoreIndex == true or disable_request == true) then
			this.requestDaniIndex = this.requestDaniIndex + 1
			
			-- 既に達人まで取得しているなら完了フラグを建てる
			if (this.requestDaniIndex >= 20) then
				DaniRequestEnd = true
			end
			
			alreadyAddIndex = true
			AddDaniScoreIndex = false
		end
		
		alreadyAddIndex = false
	end,
	
	-- 総合成績パネルを更新
	UpdataPlayerInfo = function(this)
		--Debug.PrintString("[AISongSelectAllMain] UpdataPlayerInfo")
		
		-- 左太鼓で入った時
		if (is_joinPlayer[1] == true) then
			this.player_info_:Update(this.kPlayer1p)
		-- 右太鼓で入った時
		else
			this.player_info_:Update(this.kPlayer2p)
		end
	end,
	
	-- 区間王冠を更新
	UpdateSectionCrown = function(this)
	
		if ((is_CardPlayer == true) and data ~= nil) then
			if (data.song_uniqueId ~= -1 and data.song_uniqueId < 99999) then 

				-- 左太鼓で入った時
				if (is_joinPlayer[1] == true) then
					this.player_info_:UpdataCrownSectionInfo(this.kPlayer1p, data.song_uniqueId)
				-- 右太鼓で入った時
				else
					this.player_info_:UpdataCrownSectionInfo(this.kPlayer2p, data.song_uniqueId)
				end
				
			else
				-- 左太鼓で入った時
				if (is_joinPlayer[1] == true) then
					this.player_info_:UpdataCrownSectionInfo(this.kPlayer1p, -1)
				-- 右太鼓で入った時
				else
					this.player_info_:UpdataCrownSectionInfo(this.kPlayer2p, -1)
				end
			end
		end
	end,
	
	-- AIベストスコア処理
	AIBestScoreMain = function(this)
		
		-- 移動フラグが建ったか、一定時間(1秒)が経ったらベストスコアのリクエストを掛ける
		if (songselectsong_:GetMoveFlag() == true or this:waitRequestCnt() == true) then
			this:RequestAIBestScore()
		end
		
	end,
	
	-- AIベストスコア処理(難易度選択用)
	AIBestScoreForCourseMain = function(this)
		
		-- 1秒ごとにリクエストを掛ける
		if (songselectcourse_:BestSectionScoreRequestCount() == true) then
			this:RequestAIBestScore()
		end
	end,

	-- AIのベストスコアをGSにリクエストする
	RequestAIBestScore = function(this)
		if ((is_CardPlayer == true) and data ~= nil) then
			if (data.song_uniqueId ~= -1 and data.song_uniqueId < 99999) then
				
				if (cardPlayerSelectedCourse >= EnsoLevelType.kMania) then
					if (this.is_bestCrownScoreChangeRequestOniUra == false) then
						this.is_bestCrownScoreChangeRequestOniUra = true
					else
						this.is_bestCrownScoreChangeRequestOniUra = false
					end
				end

				if (cardPlayerSelectedCourse >= EnsoLevelType.kMania) then 
					if (this.is_bestCrownScoreChangeRequestOniUra == true) then
						
						if (cardPlayerSelectedCourse == EnsoLevelType.kMania) then
							NetAccess.GetAiScoreData(data.song_uniqueId, cardPlayerSelectedCourse + 1, false)
						else
							NetAccess.GetAiScoreData(data.song_uniqueId, cardPlayerSelectedCourse - 1, false)
						end
					else
						NetAccess.GetAiScoreData(data.song_uniqueId, cardPlayerSelectedCourse, false)
					end
				else
					NetAccess.GetAiScoreData(data.song_uniqueId, cardPlayerSelectedCourse, false)
				end
			end
		end
	end,
	
	-- 難易度を決定したら区間のベストスコアをリクエスト
	SetBestSectionScore = function(this)
		
		if (songselectcourse_:GetIsSelectEnd() == true and this.is_bestSectionScoreRequest == false) then
			--　選択した楽曲及び難易度でのベストスコアの取得を行う
			NetAccess.GetAiScoreData(selectedSongData.song_uniqueId, selectedCourse1P, true)
			this.is_bestSectionScoreRequest = true
		end

	end,
	
	-- ジャンルのリストに曲のリストを追加
	InsertSongPanel = function(this)
		Debug.PrintString("InsertSongPanel")
		
		local selectedGenreIndex = 0
		
		-- 選択したジャンルパネルのインデックスを取得
		for idx = 1, #tbl_genreName do
			if (genreData[idx].genre_id == genreIdStr) then
				selectedGenreIndex = idx
				break
			end
		end

		-- 選択したジャンルパネルを消去
		table.remove(genreData, selectedGenreIndex)
		
		-- ジャンルのリストに曲のリストを追加
		for idx = 1, selectedSongNum + backPanelNum do
			table.insert(genreData, selectedGenreIndex + (idx -1), songData[idx])
		end
		Debug.PrintString("InsertSongPanel")
	end,
	
	-- もどる看板を追加
	InsertBackPanel = function(this)
		Debug.PrintString("InsertBackPanel")
		
		this.backPanelData = AIPanelData.New()
		
		this.backPanelData:SetBackPanelData()
		
		local testcnt = (math.floor(selectedSongNum / 7))
		local addBackPanel = 0
		
		for i = 1, (selectedSongNum + testcnt) do
			
			if (i % 7 == 0) then
				table.insert(songData, i, this.backPanelData)
				addBackPanel = addBackPanel + 1
			end
		end
		
		for i = 1, (selectedSongNum + addBackPanel) do
		
			if(songData[i].song_id == "back") then
				backPanelNum = backPanelNum + 1
			end
		end
		
	end,
	
	--　もどる看板をジャンル内の一番目に追加
	InsertBackPanelSingle = function(this)
		Debug.PrintString("InsertBackPanelSingle")

		table.insert(songData, 1, this.backPanelData)
		backPanelNum = backPanelNum + 1
		
	end,

	-- チュートリアルをリストから除外
	RemoveTutorial = function(this)
	
		Debug.PrintString("RemoveTutorial")
		
		for i = 1, #tbl_genreName do
			if (tbl_genreName[i] == "howto") then				
				table.remove(tbl_genreName, i)
				break
			end
		end
	end,

	-- お気に入りをリストから除外
	RemoveFavorite = function(this)
	
		Debug.PrintString("RemoveFavorite")
		Debug.PrintString(tostring(is_favoriteFolder))
		
		for i = 1, #tbl_genreName do
			if (tbl_genreName[i] == "favorite") then				
				table.remove(tbl_genreName, i)
				break
			end
		end
	end,

	-- 最近あそんだ曲をリストから除外
	RemoveRecent = function(this)
	
		Debug.PrintString("RemoveRecent")
		Debug.PrintString(tostring(is_recentFolder))
		
		for i = 1, #tbl_genreName do
			if (tbl_genreName[i] == "recent") then				
				table.remove(tbl_genreName, i)
				break
			end
		end
	end,

	-- カスタムフォルダをリストから除外
	RemoveCustom = function(this)
	
		Debug.PrintString("RemoveCustom")
		Debug.PrintString(tostring(is_customFolder))
		
		for i = 1, #tbl_genreName do
			if (tbl_genreName[i] == "custom") then				
				table.remove(tbl_genreName, i)
				break
			end
		end
	end,

	-- 段位課題曲をリストから除外
	RemoveDani = function(this)
	
		Debug.PrintString("RemoveDani")
		Debug.PrintString(tostring(is_daniFolder))
		
		for i = 1, #tbl_genreName do
			if (tbl_genreName[i] == "dani") then				
				table.remove(tbl_genreName, i)
				break
			end
		end
	end,

	-- お買い物フォルダをリストから除外
	RemoveShop = function(this)
	
		Debug.PrintString("RemoveShop")
		Debug.PrintString(tostring(is_shopFolder))
		
		for i = 1, #tbl_genreName do
			if (tbl_genreName[i] == "shop") then				
				table.remove(tbl_genreName, i)
				break
			end
		end
	end,
	
	-- 季節のIDをここでショップIDに足す
	SetUpSeasonId = function(this)
		
		if (seasonId ~= nil and seasonId ~= 0 and seasonId < 5) then
			shopIdStr = "shop"..seasonId
		end
	end,
	
	-- 各種フォルダを消す
	RemoveFolder = function(this)
		Debug.PrintString("[AISongSelectAllMain] RemoveFolder")
		if (is_aiPlayerTutorial == true) then this:RemoveTutorial() end
		if (is_favoriteFolder == false) then this:RemoveFavorite() end
		if (is_recentFolder == false) then this:RemoveRecent() end
		if (is_customFolder == false) then this:RemoveCustom() end
		if (is_daniFolder == false) then this:RemoveDani() end
		if (is_CardPlayer == false or is_shopFolder == false) then this:RemoveShop() end
	end,
	
	-- 操作ガイドの挙動メイン
	ControlGuideSongMain = function(this)
		--　一度もキー入力をせずに一定時間フォーカスが止まっていた時
		if (this:ControlGuideCount() == true and songselectsong_:GetFirstInputKatsu() == false and songselectsong_:GetFirstInputDon() == false 
			and songselectsong_:GetMoveFlag() == false and this.is_control_guide == false and SongSelectQR.is_touchFirstQRCode == false) then
--			and songselectsong_:GetMoveFlag() == false and this.is_control_guide == false and this.is_touchFirstQRCode == false) then
			
			songselectui_:StartCenterControlGuide()
			
			songselectsong_:SetControlGuideFlag(true)
			this.is_control_guide = true
			
			this.AllState_:SetState("InputWait")

		end
		
		--　プレイヤーが入力を入れたら、操作ガイドをキャンセルする
		if (this.is_control_guide == true and this:CheckInput() == true and this.is_playerCancelGuide == false) then
			songselectui_:StartDefaultControlGuide()
			songselectsong_:SetControlGuideFlag(false)
			this.is_playerCancelGuide = true
		end
		
		if (songselectsong_:GetMoveFlag() == true) then
			this.start_cnt = 0
		end

	end,
		
	--　背景の切り替え
	SwitchingBg = function(this)
		--Debug.PrintString("[AISongSelectAllMain] SwitchingBg")
		if (songselectsong_:GetEnableBgChangeFlag() == true) then
			
			songselectsong_:SetEnableBgChangeFlag(false)
			
			if (this.is_alreadyBgChange == false) then
				this.songselectbg_[1].mc_bg:GotoAndPlay("end")
				this.songselectbg_[2].mc_bg.main.bg:GotoAndStop(genreIdStrForBg)
				this.is_alreadyBgChange = true
				
			else
				this.songselectbg_[1].mc_bg.main.bg:GotoAndStop(genreIdStrForBg)
				this.songselectbg_[1].mc_bg:GotoAndPlay("start")
				this.is_alreadyBgChange = false
			end
		end
	end,
	
	-- プレイヤーが難易度を選択したかどうかを常に監視する
	CheckSelectedCourse = function(this)
		
		-- 難易度を決定したら消すエフェクトを開始する
		if (this.is_playEndEffect == false) then		
			this.don1p_:GotoAndPlay("don_effect")
			this.don2p_:GotoAndPlay("aidon_effect")
			this.is_playEndEffect = true
		end
	end,
	
	-- プレイヤーの入力情報
	CheckInput = function(this)
		if (songselectsong_:GetInputEnable() == true) then
			if(is_joinPlayer[1] == true) then
				-- 1Pの入力
				if (Input.GetTrigger(Input.PLAYER1_OK) or Input.GetTrigger(Input.PLAYER1_CANCEL)) then return true end
				if (Input.GetTrigger(Input.PLAYER1_LEFT))	then return true end
				if (Input.GetTrigger(Input.PLAYER1_RIGHT))	then return true end
			end
			
			if(is_joinPlayer[2] == true) then
				-- 2Pの入力
				if (Input.GetTrigger(Input.PLAYER2_OK) or Input.GetTrigger(Input.PLAYER2_CANCEL)) then return true end
				if (Input.GetTrigger(Input.PLAYER2_LEFT))	then return true end
				if (Input.GetTrigger(Input.PLAYER2_RIGHT))	then return true end
			end
		end
	end,
	
	-- 曲の再生
	PlaySound = function(this)
		--Debug.PrintString("[AISongSelectAllMain] PlaySound")
		this.song_play_request_ = true
		songselectsong_:SetPlaySoundFlag(false)
	end,

	-- 曲のフェードアウト
	StopSound = function(this)
		-- 再生中ならフェードアウト
		Debug.PrintString("[AISongSelectAllMain] StopSound")
		this.song_play_request_ = false
		
		if (data.song_bank_name == this.nowPlaySongName) then
			return
		end
		
		if(this.song_play_state_ == "Play" or this.song_play_state_ == "PlayWait") then
			TSound:StopBGM(330)	-- 0.33secでフェードアウト
			this.song_play_state_ = "StopWait"
		end
	end,

	-- BGMの更新
	UpdateSound = function(this)
		local is_loopPlay = false
		
		-- BGMストップ後の処理
		if(this.song_play_state_ == "StopWait") then
			Debug.PrintString("StopWait")
			-- 完全にストップしてたら
			if (TSound:IsPlayingBGM() == false) then
				-- 現在ロードしたのが選曲専用BGMの場合
				if (this.nowPlaySongName == "bgm_aisenkyoku_v12g") then
					this.song_play_state_ = "Wait"
				else
					--TSound:UnloadBank(this.nowPlaySongName)
					this.song_play_state_ = "Wait"
				end
			end
		
		-- BGMロード後の待ちフェーズ
		elseif(this.song_play_state_ == "LoadWait") then
			Debug.PrintString("LoadWait")
	
			if(TSound:LoadedBankAll() == true) then
				-- 事前に読み込んだバンク名と等しいなら曲をプレイする
				if (this.nowPlaySongName == data.song_bank_name) then
					if (data.song_bank_name == "bgm_aisenkyoku_v12g") then
						if (TSound:IsPlayingBank("bgm_aisenkyoku_v12g") == false) then
							TSound:PlayBGM(data.song_bank_name)
							Debug.PrintString("PlayBGM")		
						end
					else
						TSound:PlayBGMSongSelect(data.song_bank_name)
						Debug.PrintString("PlayBGMSongSelect")	
					end
					this.song_play_state_ = "PlayWait"
				else
				-- 事前に読み込んだバンク名と等しくないならアンロードする
					if (this.nowPlaySongName ~= "bgm_aisenkyoku_v12g") then
						--TSound:UnloadBank(this.nowPlaySongName)
						this.song_play_state_ = "Wait"
					else
						this.song_play_state_ = "Wait"
					end
				end
			end
		
		-- BGMアンロード後の待ちフェーズ
		elseif(this.song_play_state_ == "UnloadWait") then
			Debug.PrintString("UnloadWait")

			if(Common.CheckNUAssetUnload() == false) then
				this.song_play_state_ = "Wait"
			end
		
		-- 再生タイミング待ちフェーズ
		elseif(this.song_play_state_ == "Wait") then
			Debug.PrintString("Wait")

			if(this.song_play_request_ == true) then
				this.song_play_request_ = false
				
				if (data ~= nil) then
					if (data.song_bank_name ~= "bgm_aisenkyoku_v12g") then
						TSound:LoadBank(data.song_bank_name)						
					end
					
					this.nowPlaySongName = data.song_bank_name
					this.song_play_state_ = "LoadWait"
					Debug.PrintString("change_song_play_state__PlayWait")
				end
				
			end
		
		-- 再生されるまで待つフェーズ
		elseif(this.song_play_state_ == "PlayWait") then

			if (TSound:IsPlayingBGM() == true) then
				this.song_play_state_ = "Play"
			end
		
		-- 再生フェーズ
		elseif(this.song_play_state_ == "Play") then
			--Debug.PrintString("Play")

			if (TSound:IsPlayingBGM() == false and songselectsong_:GetMoveFlag() == false) then
				this.is_loopPlay = true
				
				if (data.song_bank_name == "bgm_aisenkyoku_v12g") then
					TSound:PlayBGM(data.song_bank_name)
					Debug.PrintString("PlayBGM")
				else
					TSound:PlayBGMSongSelect(data.song_bank_name)
					Debug.PrintString("PlayBGMSongSelect")
				end
				this.song_play_state_ = "PlayWait"
			end
		end
	end,
	
	-- ユーザーデータを更新
	UpdatePlayData = function(this)
		Debug.PrintString("[AISongSelectAllMain] UpdatePlayData")
		
		if (is_joinPlayer[1] == true) then
			play_data_ = PlayDataManager.GetEntryPlayData(0)
		else
			play_data_ = PlayDataManager.GetEntryPlayData(1)
		end

	end,
	
	-- ステートを更新
	Update = function(this)

		this.AllState_:Update()
		
		if (songselectsong_ ~= nil and songselectsong_.is_setUpAllOk == true) then this:UpdateSound() end
		if (this.is_allSetupOk == true) then this:ChangeAIDonMotion() end
		
		-- タイマー実行
		this.timer_:Update()

	end,
-- ここまでUpdate


	-- SongSelectQRで使っているので関数だけ作っておくシリーズ
	Set2PEntryEnable = function(this)
	end,
}
-- ここまでMain
