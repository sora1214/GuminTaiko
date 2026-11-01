-- 曲選択画面.全体シーケンスLua
-- Masayuki_Teraoka@al.bandainamco.jp

-- 使うクラスを読み込む
require("common.CreditSide")
require("common.NamePlate")
require("common.PlayerInfo")
require("common.Sound")
require("common.State")
require("common.Timer")

require("song_select.song_select_ui")
require("song_select.song_select_bg")
require("song_select.song_select_song_main")
require("song_select.song_select_course_main")
require("song_select.song_select_option_main")
require("song_select.song_select_shop_main")
require("song_select.PanelData")
require("song_select.ChallengeCompeManager")

require("song_select.song_select_qr")

require("song_select.CollaboChara")

--require("entry.qr_load")

-- このクラス
SongSelectAllMain = {
	AllState_ = State.New("SongSelectAllMain"),
	
	-- タイマー
	timer_                       = Timer.New("timer_instance"),
	
	--　ネームプレート
	name_plate_                  = {NamePlate.New("plate_1p_instance"),NamePlate.New("plate_2p_instance")},
	
	--　クレジット表記
	credit_side_                 = {CreditSide.New("credit_side_instance_1"),CreditSide.New("credit_side_instance_2")},
	
	--　総合成績パネル
	player_info_                 = {PlayerInfo.New("playerinfo_instance_1"),PlayerInfo.New("playerinfo_instance_2")},
	
	--　背景
	songselectbg_                = {SongSelectBg.New("bg_instance_1"), SongSelectBg.New("bg_instance_2")},
	
	--コラボキャラ
	collaboChara_			     = {CollaboChara.New("event1p",1), CollaboChara.New("event2p",2)},
	
	start_cnt                    = 0,						-- セットアップ完了後からのカウント
	wait_start_cnt               = 0.1 * Common.FPS,        -- セットアップ完了後から曲選択シーケンスに入るまでのウェイト
	
	end_cnt                      = 0,                       -- 最後のEndシーケンスに入ってからのカウント（通常）
	wait_end_cnt                 = 0.1 * Common.FPS,        -- 最後のEndシーケンスに入ってからC++側にLuaの終了を伝えるまでのウェイト
	
	entry_end_cnt                = 0,                       -- 乱入Endシーケンスに入ってからのカウント（乱入時）
	wait_entry_end_cnt           = 1.5 * Common.FPS,        -- 乱入Endシーケンスに入ってからEndシーケンスに入るまでのウェイト
	
	control_cnt                  = 0,                       -- 曲選択画面に遷移してからキー入力が何も無い時にカウント
	wait_control_cnt             = 10 * Common.FPS,         -- 曲選択画面に遷移してから操作ガイドを大きく表示するまでのウェイト
		
	start_debug_cnt			     = 0,						--　デバッグ用のカウント
	wait_debug_cnt			     = 10.0 * Common.FPS,		--　この数字のタイミングでQRコードのフラグON（デバッグ用
	
	start_dani_request_cnt	     = 0,						--　段位リクエスト用のカウント
	wait_dani_request_cnt	     = 0.5 * Common.FPS,		--　この数字のタイミングで段位のリクエストをON(0.5秒)

	kResultWaiting			     = 1,						-- 開始待機
	kResultRunning			     = 2,						-- 実行中
	kResultCanseled			     = 3,						-- キャンセルされた（モード選択に戻る）
	kResultDecided			     = 4,						-- 決定された（難易度選択へ進む）
	kResultShop				     = 5, 						-- ショップ機能の開始
	
	kOpenGenreNum                = 1,						-- 1度に何個のジャンル看板を開いたか（同時に何個も開けないので1固定)
	
	song_play_state_             = "Wait",					--　BGMのステート
	song_play_request_           = false,					--　BGMのリクエストをしたか

	nowPlaySongName              = "",						--　現在再生中の曲名
	
--	fromStateName			     = "",						-- どこのシーケンスからきたのかを保存する
	
	is_control_guide             = false,					-- 操作ガイドが大きく表示されたか
	
	is_songTimeUp                = false,					--　曲を選択中にタイムアウトになったか
	is_courseTimeUp              = false,					--　難易度を選択中にタイムアウトになったか
	is_alreadyBgChange           = false,					-- 背景の切り替えを開始したか
	is_playerCancelGuide         = false,					-- 操作ガイドが大きくなってから、プレイヤーの入力でキャンセルされたか
	is_courseTimeUpSe            = false,					-- 難易度選択時にタイムアウトになった時のSEを鳴らしたか
--	is_touchFirstQRCode		     = false,					-- 一度でもQRコードをタッチしたか
--	is_QRCodeTouching		     = false,					-- QRタッチシーケンス中か
	
	backPanelData         	     = 0,						-- 戻る看板のデータを入れる変数
	requestDaniIndex_1P		     = 16,						-- リクエストを掛ける段位のインデックス(1P)
	requestDaniIndex_2P		     = 16,						-- リクエストを掛ける段位のインデックス(2P)
	
	Init = function(this)
		Debug.PrintString("[SongSelectAllMain] Init_Start")
		
		-- 各クラスの作成及びLumenファイルの読み込み
		this.AllState_.func_["Begin"] = function()
			-- 各種パーツ読み込み
			Debug.PrintString("[SongSelectAllMain] SequenceStart_Begin")

			songselectui_     = SongSelectUi.New("song_of_number_instance","control_guide_instance")
			songselectsong_   = SongSelectSongMain.New(0)
			songselectcourse_ = SongSelectCourseMain.New(1, this)
			songselectshop_   = SongSelectShopMain.New(0)
			
			songselectcourse_:LoadMovieCourseMain()
			songselectshop_:LoadMovieShopMain()
			
			this.timer_:LoadMovie()
			
			-- 二つ分必要なもの
			for idx = 1, 2 do
				this.name_plate_[idx]:LoadMovie()
				this.credit_side_[idx]:LoadMovie()
				this.player_info_[idx]:LoadMovie()
				this.songselectbg_[idx]:LoadMovieBg()
				this.collaboChara_[idx]:CollaboCharaLoadMovie()
			end
			
			songselectui_:LoadMovieUi()

			-- ＱＲ読み込み
			SongSelectQR:Init()
--			QRLoad:Init()

			this.AllState_:SetState("Loading")
			Debug.PrintString("[SongSelectAllMain] SequenceEnd_Begin")
		end
		
		-- 総合成績パネルのロード待ち
		this.AllState_.func_["Loading"] = function()
		
			-- プレイヤー情報
			if(this.player_info_[1]:Loading() == false) then
				return
			end
			if(this.player_info_[2]:Loading() == false) then
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
				
				-- 季節のIDをここで代入
				this:SetUpSeasonId()

				-- ユーザーサイドのクレジット情報
				this:InitCreditSide()
				
				-- プレイヤー情報（カード）
				this:InitPlayerInfo()
				
				-- 背景
				this.songselectbg_[1]:SetupBg()
				this.songselectbg_[2]:SetupBg()
				
				-- コラボキャラ
				this.collaboChara_[1]:CollaboCharaSetup()
				this.collaboChara_[2]:CollaboCharaSetup()

				-- その他UI
				songselectui_:SetupUi()
				songselectui_:InitNumberOfSongs()
				songselectui_:SetTextControlGuide()				
				
				-- 各画面のイニシャライズ（曲・難易度・ショップ）
				songselectsong_:Init()
				songselectcourse_:Init()
				songselectshop_:Init()
				
				--　3Dドンのイニシャライズ
				this:InitDon3D(is_joinPlayer[1], is_joinPlayer[2])
				
				--　ネームプレートのイニシャライズ
				this:InitNamePlate(is_joinPlayer[1], is_joinPlayer[2])
				
				--　エントリー受付ウィンドウ
				this:CreditSideVisible()
				
				-- 大会・挑戦状アイコン用マネージャーのセットアップ
				ChallengeCompeManager:SetUp()
				
				
				-- ＱＲ読み込みウィンドウのセットアップを行う
				SongSelectQR:Setup()
--				QRLoad:Setup()

				-- ユーザーデータ一度取得
				play_data_[1]                  = PlayDataManager.GetEntryPlayData(0)
				play_data_[2]                  = PlayDataManager.GetEntryPlayData(1)
				
				-- そのクレジット中で最後に設定した内容を取得する
				user_setting_data_[1]          = PlayDataManager.GetEnsoModeSetting(0)
				user_setting_data_[2]          = PlayDataManager.GetEnsoModeSetting(1)

				-- そのクレジット中で最後に設定した内容を取得する
				user_setting_Original_data_[1] = PlayDataManager.GetOriginalEnsoModeSetting(0)
				user_setting_Original_data_[2] = PlayDataManager.GetOriginalEnsoModeSetting(1)

				-- オプションの設定
				songselectcourse_:SetUpSongSelectOption()
				
				is_freePlay = PlayDataManager.IsFreePlay()
				
				for idx = 1, 2 do
				
					-- チュートリアルを見ているかどうか(チュートリアルはカード・コイン共通)
					is_playerTutorial[idx] = play_data_[idx].user_data.disp_info.is_tutorial_play
					
					--　以下カードユーザー限定の事項
					if (play_data_[idx].user_type == UserType.kCard) then
						-- ユーザー情報
						is_CardPlayer[idx] = true
						this.player_info_[idx]:SetVisible(true)
						this.player_info_[idx]:SetPlayerInfo(idx,-1)
						
						-- プレイヤーが設定した難易度を取得
						cardPlayerSelectedCourse[idx] = play_data_[idx].user_data.totalRecordInfo.disp_crown_level

						-- プレイヤーが設定したオプションを設定
						songselectcourse_:SetOptionLastDiff(idx)						
					end
					
					-- おにを解放しているかどうかのフラグの上書き
					playerOpenOni[idx] = play_data_[idx].user_data.disp_info.is_oni_open
					
					if (playerOpenOni[idx] == true) then
						playerOpenLevel[idx] = kPlayerOpenOni
					end
				end
				
				this:RequestDaniBestScore()
				
				-- C側に準備完了通知
				Common.LuaPrepareFinish()

				-- オプションの初期設定
				songselectcourse_:InitOptionIcon()
				
				-- -- エントリーしている全てのユーザーがチュートリアルを視聴済みかどうか
				if (player_num < 2) then
					if (is_joinLeft) then
						if (is_playerTutorial[1] == true) then is_already_play_tutorial_ = true end
					elseif (is_joinRight) then
						if (is_playerTutorial[2] == true) then is_already_play_tutorial_ = true end
					end
				else
					if (is_playerTutorial[1] == true and is_playerTutorial[2] == true) then is_already_play_tutorial_ = true end
				end
				
				this.AllState_:SetState("StartWait")
				Debug.PrintString("[SongSelectAllMain] SequenceEnd_Loading")

			end
		end
		
		--　曲選択シーケンス前のウェイト
		this.AllState_.func_["StartWait"] = function()
		
			Debug.PrintString("[SongSelectAllMain] SequenceStart_StartWait")
			
			if(this:waitCnt() == true) then
				
				backPanelNum   = 0
				this.start_cnt = 0
				this:RemoveFolder()

				songselectui_:StartControlGuide()

				this:CreateGenreData()

				-- ＱＲ読み込み表示開始
				SongSelectQR:TouchWaitStart(SceneType.kSongSelect)

				this.AllState_:SetState("SongSelectMain")
				
				-- ＱＲ読み込み表示開始
--				SongSelectQR:TouchWaitStart(SceneType.kSongSelect)
--				QRLoad:TouchWaitStart(true,SceneType.kSongSelect)

				this.collaboChara_[1]:CollaboCharaFadeIn()
				this.collaboChara_[2]:CollaboCharaFadeIn()
				
				Debug.PrintString("[SongSelectAllMain] SequenceEnd_StartWait")
			end
		end

		--　曲選択シーケンス
		this.AllState_.func_["SongSelectMain"] = function()
			--Debug.PrintString("[SongSelectAllMain] SequenceStart_SongSelectMain")

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
--			if (songselectsong_:GetOpenFolder() == true and this.is_QRCodeTouching == false) then
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
			
			-- 段位のベストスコアをリクエスト
			if(this:DaniRequestCount() == true) then
				this:RequestDaniBestScore()
			end
			
			this:UpdataPlayerInfo()
			
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
					this.collaboChara_[1]:CollaboCharaToDecideMotion()
					this.collaboChara_[2]:CollaboCharaToDecideMotion()
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
				songselectshop_:SetCalledPlayer(songselectsong_.selectedEndPlayer)
				songselectshop_.is_start = true
				songselectsong_:Set2PEntryEnableFlag(false)

				-- 楽曲購入を選んだらＱＲ止める
				SongSelectQR:TouchWaitFinish()

				this.AllState_:SetState("ShopMain")

			end
			
			-- メインシーケンスの時かつフォルダを開いてない時
			if (songselectsong_.State_.state_ == "Main" and songselectsong_:GetOpenFolder() == false) then	
				SongSelectQR:UpdateQR(this,"SongSelectMain")
--				this:UpdateQR("SongSelectMain")
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
			
			-- 段位のベストスコアをリクエスト
			if(this:DaniRequestCount() == true) then
				this:RequestDaniBestScore()
			end

			--　難易度が決まったら直ぐにタイマーを止める
			if (songselectcourse_.is_timerStop == true) then this.timer_:StopCount() end
			
			--　難易度が確定したら次のシーンをセットしEndシーケンスへ
			if (songselectcourse_:GetResult() == this.kResultDecided) then
				nextMode = SceneType.kEnsoGame
				this.AllState_:SetState("End")
			
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
				SongSelectQR:TouchWaitStart(SceneType.kSongSelect)

				this.AllState_:SetState("SongSelectMain")

			end
			
			-- メインシーケンスの時かつタイムアップでないとき
--[[
-- 難易度選択でＱＲ読まない
			if (songselectcourse_.State_.state_ == "Main" and songselectcourse_.is_timeUp ~= true) then
				SongSelectQR:UpdateQR(this,"CourseSelectMain")
				this:UpdateQR("CourseSelectMain")
			end
]]
		end
		
		--　楽曲購入シーケンス
		this.AllState_.func_["ShopMain"] = function()
			--Debug.PrintString("[SongSelectAllMain] ShopMain")
			
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
				
				-- 乱入可能フラグを建てる
				this:Set2PEntryEnable()
				
				-- ＱＲ読み込み表示開始
				SongSelectQR:TouchWaitStart(SceneType.kSongSelect)

				this.AllState_:SetState("SongSelectMain")
			
			--　購入したとき
			elseif (songselectshop_:GetResult() == this.kResultDecided) then
				
				reBuyFlag = true
				
				this.player_info_[1]:UpdateTokenInfo(1)
				this.player_info_[2]:UpdateTokenInfo(2)

				this.timer_:StartCount()
				songselectsong_:SetShopBackFlag(true)
				songselectsong_:SetTokenInformation()
				songselectshop_:SetResultType(this.kResultWaiting)
				songselectshop_:ReStartShop()
				this:UpdatePlayData()
				
				-- 乱入可能フラグを建てる
				this:Set2PEntryEnable()
				
				-- ＱＲ読み込み表示開始
				SongSelectQR:TouchWaitStart(SceneType.kSongSelect)

				this.AllState_:SetState("SongSelectMain")
			end
			
		end
		
		--　大きい操作ガイドの表示シーケンス
		this.AllState_.func_["InputWait"] = function()
			
			SongSelectQR:UpdateQR(this,"InputWait")
--			this:UpdateQR("InputWait")
			
			if(this.timer_:IsZero() == true) then
				Debug.PrintString("[InputWait] TimeUp")
				this.AllState_:SetState("SongSelectMain")
				return
			end

			if (is_touchQRCode == true and this.timer_:IsZero() == false and songselectsong_:GetMoveFlag() == false) then
				this.AllState_:SetState("SongSelectMain")
				return
			end
			
			--Debug.PrintString("[SongSelectAllMain] InputWait")
			this:ControlGuideSongMain()
			
			--　プレイヤーが入力して操作ガイドをキャンセルしたとき
			if(this.is_playerCancelGuide == true) then
				this.AllState_:SetState("SongSelectMain")
				Debug.PrintString("[SongSelectAllMain] SequenceEnd_InputWait")
			end
		end
		
		--　QRコード使用中のステート
		this.AllState_.func_["QRState"] = function()
			Debug.PrintString("[SongSelectAllMain] QRState")
			SongSelectQR:UpdateQR(this,"")
--			this:UpdateQR("")
		end

		--　二人目がエントリーした場合のEndに遷移する前のシーケンス
		this.AllState_.func_["EntryEnd"] = function()
			Debug.PrintString("[SongSelectAllMain] EntryEnd")
			
			--　SEが鳴りやむまでのウェイトを掛ける
			if (this:EntryWaitEnd() == true) then
				TSound:StopBank("se_common_v12a")
				this.AllState_:SetState("End")
				return
			end
		end
		
		--　全体シーケンスのEnd
		this.AllState_.func_["End"] = function()
			Debug.PrintString("[SongSelectAllMain] End")
			
			SongSelectQR:TouchWaitFinish()
--			QRLoad:TouchWaitFinish()
			
			--　指定のフレームをカウント且つSEが止まっていれば終了させる
			if (this:WaitEndCnt() == true and TSound:IsPlayingBank("se_common_v12a") == false) then
				Common.LuaFinish()
			else
				TSound:StopBank("se_common_v12a")
				return
			end
		end
		Debug.PrintString("[SongSelectAllMain] Init_End")
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
		Debug.PrintString("[SongSelectAllMain] waitCnt")

		this.start_cnt = this.start_cnt + 1
		
		if (this.start_cnt >= this.wait_start_cnt) then
			this.start_cnt = 0
			return true
		else return false
		end
	end,
	
	--　C++側にLuaの終了を伝えるまでのカウント
	WaitEndCnt = function(this)
		Debug.PrintString("[SongSelectAllMain] WaitEndCnt")

		this.end_cnt = this.end_cnt + 1
		
		if (this.end_cnt >= this.wait_end_cnt) then
			this.end_cnt = 0
			return true
		else return false
		end
	end,
	
	--　乱入時のSEが鳴りやむまでのカウント
	EntryWaitEnd = function(this)
		Debug.PrintString("[SongSelectAllMain] EntryWaitEnd")

		this.entry_end_cnt = this.entry_end_cnt + 1
		
		if (this.entry_end_cnt >= this.wait_entry_end_cnt) then
			this.entry_end_cnt = 0
			return true
		else return false
		end
	end,
	
	-- 操作ガイドのフレームカウント
	ControlGuideCount = function(this)
		--Debug.PrintString("[SongSelectAllMain] ControlGuideCount")
		this.start_cnt = this.start_cnt + 1
		
		if (this.start_cnt >= this.wait_control_cnt) then
			this.start_cnt = 0
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
	InitDon3D = function(this, is_joinLeft, is_joinRight)
	
		Debug.PrintString("InitDon3D")
		
		this.don1p_ = Lumen.GetMovieClip("don_1p",true)
		this.don2p_ = Lumen.GetMovieClip("don_2p",true)

		if (is_joinLeft == true) then
			this.don1p_:SetVisible(true)
			Don.SetLoopAnimation(0,"result_clear_loop",true)

			Don.ChangeDonForPlayData(0,Don.kType_Don)
			Don.CameraReverse(0,false)
		else this.don1p_:SetVisible(false)
		end
		
		if (is_joinRight == true) then
			this.don2p_:SetVisible(true)
			Don.SetLoopAnimation(1,"result_clear_loop",true)

			Don.ChangeDonForPlayData(1,Don.kType_Katsu)
			Don.CameraReverse(1,true)
		else this.don2p_:SetVisible(false)
		end
		
	end,
	
	-- ネームプレートのイニシャライズ
	InitNamePlate = function(this, is_joinLeft, is_joinRight)
		Debug.PrintString("[SongSelectAllMain] InitNamePlate")
		this.name_plate_[1]:Setup()
		this.name_plate_[2]:Setup()
		this.name_plate_[1]:SetVisible(false)
		this.name_plate_[2]:SetVisible(false)
		
		-- ネームプレートの準備
		if (is_joinLeft == true) then
			this.name_plate_[1]:SetVisible(true)
			this.name_plate_[1]:SetPlayerInfo(1)
		else 
			this.name_plate_[1]:SetVisible(false)
		end

		if (is_joinRight == true) then
			this.name_plate_[2]:SetVisible(true)
			this.name_plate_[2]:SetPlayerInfo(2)
		else 
			this.name_plate_[2]:SetVisible(false)
		end

	end,
	
	-- 左右のクレジット表示のイニシャライズ
	InitCreditSide = function(this)
		Debug.PrintString("InitCreditSide")
	
		-- クレジット表示の準備
		this.credit_side_[1]:Setup(1)
		this.credit_side_[1]:SetVisible(false)
		this.credit_side_[2]:Setup(2)
		this.credit_side_[2]:SetVisible(false)
		
	end,
	
	-- 総合成績パネルのイニシャライズ
	InitPlayerInfo = function(this)
		Debug.PrintString("InitPlayerInfo")
		
		this.player_info_[1]:Setup()
		this.player_info_[1]:SetVisible(false)
		this.player_info_[2]:Setup()
		this.player_info_[2]:SetVisible(false)

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
			
			songData[i] = PanelData.New() 
			
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
		
			genreData[i] = PanelData.New() 
			
			genreData[i]:SetGenreInfoData(i)
		end
	end,
	
	-- ベストスコア表示を更新
	UpdateBestScore = function(this)
		--Debug.PrintString("[SongSelectAllMain] UpdateBestScore")
		for idx = 1, 2 do
			if (is_CardPlayer[idx] == true and data ~= nil) then
				if (data.song_uniqueId ~= -1 and data.song_uniqueId < 99999) then 
					this.player_info_[idx]:UpdateBestScoreInfo(idx, data.song_uniqueId) 
				else this.player_info_[idx]:UpdateBestScoreInfo(idx, -1)
				end
			end
		end
	end,
	
	-- 段位のベストスコアを取得
	RequestDaniBestScore = function(this)
		
		if (this.requestDaniIndex_1P >= 20 and this.requestDaniIndex_2P >= 20) then
			return
		elseif (this.requestDaniIndex_1P >= 20 and DaniRequestEnd_1P == true) then
			this:RequestDaniBestScore_2P()
		else
			this:RequestDaniBestScore_1P()
		end
		
	end,
	
	-- 段位のベストスコアを取得(1P側)
	RequestDaniBestScore_1P = function(this)
		
		if (is_CardPlayer[1] == false) then
			this.requestDaniIndex_1P = 20
			DaniRequestEnd_1P = true
			return
		end
		
		local clear_level = play_data_[1].user_data.daniRecordInfo.normal_rank[this.requestDaniIndex_1P]
		local disable_request = false
		
		if (clear_level > DaniClearRank.kNoPlay) then
			NetAccess.GetDaniScore(0, this.requestDaniIndex_1P)
		else
			-- 該当の段位を遊んでないなら値を増やすフラグを建てる
			disable_request = true
		end
		
		globalRequestDaniIndex_1P = this.requestDaniIndex_1P
	
		if (AddDaniScoreIndex_1P == true or disable_request == true) then
			this.requestDaniIndex_1P = this.requestDaniIndex_1P + 1
			
			-- 既に達人まで取得しているなら完了フラグを建てる
			if (this.requestDaniIndex_1P >= 20) then
				DaniRequestEnd_1P = true
			end
			
			alreadyAddIndex_1P = true
			AddDaniScoreIndex_1P = false
		end
		
		alreadyAddIndex_1P = false
		
	end,
	
	-- 段位のベストスコアを取得(2P側)
	RequestDaniBestScore_2P = function(this)
		
		if (is_CardPlayer[2] == false) then
			this.requestDaniIndex_2P = 20
			DaniRequestEnd_2P = true
			return
		end

		local clear_level = play_data_[2].user_data.daniRecordInfo.normal_rank[this.requestDaniIndex_2P]
		local disable_request = false
		
		if (clear_level > DaniClearRank.kNoPlay) then
			NetAccess.GetDaniScore(1, this.requestDaniIndex_2P)
		else
			-- 該当の段位を遊んでないなら値を増やすフラグを建てる
			disable_request = true
		end
		
		globalRequestDaniIndex_2P = this.requestDaniIndex_2P
		
		if (AddDaniScoreIndex_2P == true or disable_request == true) then
			this.requestDaniIndex_2P = this.requestDaniIndex_2P + 1
			
			-- 既に達人まで取得しているなら完了フラグを建てる
			if (this.requestDaniIndex_2P >= 20) then
				DaniRequestEnd_2P = true
			end
			
			alreadyAddIndex_2P = true
			AddDaniScoreIndex_2P = false
		end
		
		alreadyAddIndex_2P = false
	end,

	
	-- 総合成績パネルを更新
	UpdataPlayerInfo = function(this)
		--Debug.PrintString("[SongSelectAllMain] UpdataPlayerInfo")
		for idx = 1, 2 do
			this.player_info_[idx]:Update(idx) 
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
		
		this.backPanelData = PanelData.New()
		
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
		Debug.PrintString("[SongSelectAllMain] RemoveFolder")
		if (is_already_play_tutorial_ == true) then this:RemoveTutorial() end
		if (is_favoriteFolder == false) then this:RemoveFavorite() end
		if (is_recentFolder == false) then this:RemoveRecent() end
		if (is_customFolder == false) then this:RemoveCustom() end
		if (is_daniFolder == false) then this:RemoveDani() end
		if ((is_CardPlayer[1] == false and is_CardPlayer[2] == false) or is_shopFolder == false) then this:RemoveShop() end
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

	-- エントリーのチェック関数
	CheckEntry = function(this)
		local is_entry = false
		local now_coin = PlayDataManager.GetNowCoin()
		local need_cost = PlayDataManager.GameCost1

		if(player_num == 1) then
			need_cost = (PlayDataManager.GameCost2 - PlayDataManager.GameCost1)
		elseif(player_num == 2) then
			now_coin = 0
		end

		if(now_coin >= need_cost or is_freePlay == true) then
		-- １Ｐ側ドン入力
			if((Input.GetTrigger(Input.PLAYER1_OK) == true) or (Input.GetTrigger(Input.PLAYER1_CANCEL) == true)) then
				-- まだエントリーしてない場合のみ
				if(is_joinPlayer[1] == false) then
					-- 「どん（左）」
					Debug.PrintString("[SongSelectAllMain] LeftPlayerLogIn")
					TSound:Play("se_common_v12a","don_l")
					is_entry = true
				end
		-- ２Ｐ側ドン入力
			elseif((Input.GetTrigger(Input.PLAYER2_OK) == true) or (Input.GetTrigger(Input.PLAYER2_CANCEL) == true)) then
				-- まだエントリーしてない場合のみ
				if(is_joinPlayer[2] == false) then
					-- 「どん（右）」
					Debug.PrintString("[SongSelectAllMain] RightPlayerLogIn")
					TSound:Play("se_common_v12a","don_r")
					is_entry = true
				end
			end
		end
		return is_entry
	end,
	
	-- 二人目エントリー
	SecondPlayerJoinToEntry = function(this)
		
		local is_entry
		
		if (songselectsong_ ~= nil and songselectsong_:Get2PEntryEnableFlag() == true) then 
			is_entry = this:CheckEntry()
		end
		
		if(is_entry == true) then
			TSound:Play("se_common_v12a","entry_2p_add")

			nextMode = SceneType.kEntry
			this.AllState_:SetState("EntryEnd")
		end
	end,
	
	--　エントリー受付ウィンドウ
	CreditSideVisible = function(this)
		Debug.PrintString("[SongSelectAllMain] CreditSideVisible")
		-- 二人目エントリー受付ウィンドウ
		if(is_joinPlayer[1] == false) then
			if (playSongCount < 2) then this.credit_side_[1]:SetVisible(true) end
		else this.credit_side_[1]:SetVisible(false)
		end
		
		if(is_joinPlayer[2] == false) then
			if (playSongCount < 2) then this.credit_side_[2]:SetVisible(true) end
		else this.credit_side_[2]:SetVisible(false)
		end

	end,
	
	--　背景の切り替え
	SwitchingBg = function(this)
		--Debug.PrintString("[SongSelectAllMain] SwitchingBg")
		if (songselectsong_:GetEnableBgChangeFlag() == true) then
			
			songselectsong_:SetEnableBgChangeFlag(false)

			if(this.songselectbg_[1]:IsVariableBackground() == true) then
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
		--Debug.PrintString("[SongSelectAllMain] PlaySound")
		this.song_play_request_ = true
		songselectsong_:SetPlaySoundFlag(false)
	end,

	-- 曲のフェードアウト
	StopSound = function(this)
		-- 再生中ならフェードアウト
		Debug.PrintString("[SongSelectAllMain] StopSound")
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
				if (this.nowPlaySongName == "bgm_senkyoku_v12a") then
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
					if (data.song_bank_name == "bgm_senkyoku_v12a") then
						if (TSound:IsPlayingBank("bgm_senkyoku_v12a") == false) then
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
					if (this.nowPlaySongName ~= "bgm_senkyoku_v12a") then
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
					if (data.song_bank_name ~= "bgm_senkyoku_v12a") then
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
				
				if (data.song_bank_name == "bgm_senkyoku_v12a") then
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
	
--[[
	-- QRコード処理
	UpdateQR = function(this, state_)
	
		-- QRコードリーダの処理
		local qr_result = QRLoad:Update()
		-- 結果で分岐
		if(qr_result ~= 0) then
			
			-- QR以外のステートから来たのなら保存しておく
			if (state_ ~= "") then
				this.fromStateName = state_
			end
			
			-- QRタッチ中フラグを建てる
			this.is_QRCodeTouching = true
			
			-- 乱入できないようにフラグを設定する
			songselectsong_:Set2PEntryEnableFlag(false)
			
			-- タイマーカウントを停止
			this.timer_:StopCount()
			this.AllState_:SetState("QRState")
			-- 通信中などのウィンドウが出ているので、何かやってるのは止めた方がいい
			
			this.is_touchFirstQRCode = true
			if(songselectsong_:GetControlGuideFlag() == true) then songselectui_:StartDefaultControlGuide() end
			songselectsong_:SetControlGuideFlag(false)
		 
			if(qr_result == 2) then
				-- 成功、カード読み込み領域のQR部分にデータが入っている。
				-- Debug.PrintString("success")
				QRLoad:TouchWaitStart(true,SceneType.kSongSelect)

				-- カード読み込み領域から選曲IDを取得
				local musicId = QR.GetSongSelectMusicIDFromTouchData()
				if(musicId > 0) then
					-- 曲指定に行く
					Debug.PrintString("song jump")

					-- タッチした情報をプレイヤー情報に入れる→後で「QR使用」が実行される
					QR.UpdateUserQRFromTouchData(0)
					QR.UpdateUserQRFromTouchData(1)

					-- QR読み込み停止（QR後のアニメーションが終わるまでQR読み込み停止）
--					QRLoad:TouchWaitFinish()

					is_touchQRCode = true
					QRSelectSongUniqueId = musicId
					-- タイマーカウントを再開
					this.timer_:StartCount()
					-- 乱入可能フラグを建てる
					this:Set2PEntryEnable()
					-- 終わったら戻す
					this.is_QRCodeTouching = false

					-- 入ってきたシーケンスに戻す
					this.AllState_:SetState(this.fromStateName)
				end
			elseif(qr_result == -1) then
				-- エラー 何もしない
				Debug.PrintString("QR ERROR")
				QRLoad:TouchWaitStart(true,SceneType.kSongSelect)
				
				-- タイマーカウントを再開
				this.timer_:StartCount()
				-- 乱入可能フラグを建てる
				this:Set2PEntryEnable()
				-- 終わったら戻す
				this.is_QRCodeTouching = false

				-- 入ってきたシーケンスに戻す
				this.AllState_:SetState(this.fromStateName)
				return
			else
				return
			end
		end
	
	end,
]]
	
	-- 乱入可能フラグを建てる
	Set2PEntryEnable = function(this)
	
		-- 再度乱入出来るように設定しなおす
		if (playSongCount < 2 and player_num == 1) then 
			songselectsong_:Set2PEntryEnableFlag(true) 
		else 
			songselectsong_:Set2PEntryEnableFlag(false)
		end

	end,
	
	-- ユーザーデータを更新
	UpdatePlayData = function(this)
		Debug.PrintString("[SongSelectAllMain] UpdatePlayData")
		play_data_[1] = PlayDataManager.GetEntryPlayData(0)
		play_data_[2] = PlayDataManager.GetEntryPlayData(1)

	end,
	
	-- ステートを更新
	Update = function(this)

		this.AllState_:Update()
		if (nextMode ~= SceneType.kEntry) then this:SecondPlayerJoinToEntry() end
		
		this:SwitchingBg()
		if (songselectsong_ ~= nil and songselectsong_.is_setUpAllOk == true) then this:UpdateSound() end

		-- タイマー実行
		this.timer_:Update()

	end,
-- ここまでUpdate

	-- 外からコラボキャラに決定モーションをさせる
	StartCollaboDecide = function(this, playerSide)
		Debug.PrintString("StartCollaboDecide ")
		this.collaboChara_[playerSide]:CollaboCharaToDecideMotion()
	end,
}
-- ここまでMain
