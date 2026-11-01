-- AI曲選択画面.曲選択メインシーケンスLua
-- Masayuki_Teraoka@al.bandainamco.jp

AISongSelectSongMain = {}
-- 使うクラスを読み込む
require("common.Sound")
require("ai_song_select.ai_song_select_multi_board")

-- このクラス
function AISongSelectSongMain.New(timer_set)
	return
	{
		State_ = State.New("AISongSelectSongMain"),	-- このクラス用のStateクラスを作成
		
		--　フォーカスを動かした時のアニメーション用のラベル名
		tbl_SongKanbanMoveLabel = {"kanban_title_anim_d", "kanban_title_anim_u"},
		
		mc_main,											--　main　のMCを格納
	
		kKanbanMoveDown             = 1,						--　右カツを叩いた時の定数
		kKanbanMoveUp	            = 2,						--　左カツを叩いた時の定数
		
		multi_board_                = {},						--　何にでもなれるパネル（フォルダ、曲、閉じるなど）
		
		save_current_index          = {},						--　各フォルダを閉じたときの位置を記録しておく変数
		
		start_input_cnt             = 0,						-- セットアップが完了してメインに遷移するまでのカウント　
		wait_input_cnt              = 0.8 * Common.FPS,       	-- セットアップが完了してからメインに遷移するまでのウェイト
				
		stay_cnt                    = 0,						-- フォーカスを動かした直後からのカウント
		wait_stay_cnt               = 0.6 * Common.FPS,			-- フォーカスを移動後ここの秒数に達するとcursorMoveFlagをfalseに変更
	
		play_vo_count               = 0,						-- ジャンル名を呼び始めるまでのカウント
		wait_voice_cnt              = 1 * Common.FPS,			-- ここで設定した秒数に達するとボイスを再生
		
		timeup_start_cnt            = 0,						-- タイムアップ時に始まるカウント
		wait_timeup_move_cnt        = 0.5 * Common.FPS,			-- この値になったらタイムアップシーケンスが動き始める
		
		start_icon_change_cnt       = 0,						--　アイコンが切り替わってからのカウント
		wait_icon_change_cnt        = 1.0 * Common.FPS,			--　この数字のタイミングでアイコンが順番に切り替わっていく
		
		INPUT_1P_LEFT			    = 1,						-- プレイヤー/左カツ
		INPUT_1P_RIGHT			    = 2,						-- プレイヤー/右カツ
		INPUT_1P_DECIDE			    = 3,						-- プレイヤー/ドン
		INPUT_2P_LEFT			    = 4,						-- プレイヤー/左カツ
		INPUT_2P_RIGHT			    = 5,						-- プレイヤー/右カツ
		INPUT_2P_DECIDE			    = 6,						-- プレイヤー/ドン
	
		kPops					    = SongGenre.kPops,			-- ポップスの定数
		kAnime					    = SongGenre.kAnime,			-- アニメの定数
		kKids					    = SongGenre.kKids,          -- キッズの定数
		kVocalo					    = SongGenre.kVocalo,        -- ボカロの定数
		kGame					    = SongGenre.kGame,          -- ゲームの定数
		kNamco					    = SongGenre.kNamco,         -- ナムオリの定数
		
		kPanelNum				    = 8,						-- 画面に表示するパネルの数
		
		kScrollOffsetTypeWait	    = 1,						-- 待機
		kScrollOffsetTypeMoveU	    = 2,						-- 上へ移動＝下の曲を選択。2が中央
		kScrollOffsetTypeMoveD	    = 3,						-- 下へ移動＝上の曲を選択。1が中央
		
		kOpenFolderChangeFrame		= 114,						-- フォルダを開いた時の板を切り替えるフレーム
		kCloseFolderChangeFrame		= 219,						-- フォルダをとじた時の板を切り替えるフレーム
				
		resultType                  = kResultWaiting,			-- 最終的に選択した結果
		
		kResultWaiting			    = 1,						-- 開始待機
		kResultRunning			    = 2,						-- 実行中
		kResultCanseled			    = 3,						-- キャンセルされた（モード選択に戻る）
		kResultDecided			    = 4,						-- 決定された（難易度選択へ進む）
		kResultShop				    = 5, 						-- ショップ機能の開始
		
		kSelectNumber			    = 1,						-- 選択中の看板
		scrollDirection 		    = 0,						-- スクロール方向
		
		songPanelIndexOffsetType    = 1, 						-- 使用するオフセットテーブルの種類

		currentSongIndex            = 1,						-- 選択中の板Index
		
		openOffset                  = 0,						-- フォルダを開いた際のインデックスのズレを修正するオフセット
		panelNum                    = 0,						-- パネルの枚数
		mc_Kanban                   = 0,						-- main/kanban の MC を入れておく
		
		playSoundFlag               = false,					-- 曲を再生したか
		
		kopenPanelWaitCount         = 61,						-- スクロールしてフォーカスが止まってからパネルが開くまでのフレーム
		openPanelWaitCount          = 0,						-- 上記の定数をスクロールのたびに代入
		selected_last_genre         = "pops",					-- 前曲で選んだジャンルを格納する
		QRSelectSongUniqueId		= 0,						-- QRコードで読み取った楽曲のユニークID
		QRgenreIndexStr				= "",						-- QRコードで読み取った楽曲のジャンルID(str)
		
		is_setUpAllOk				= false,					--　全セットアップが完了したか
		is_controlGuideZoomFlag 	= false,					-- 操作ガイドが大きい状態か
		is_openFolder 				= false,					-- フォルダを開いたかどうか
		is_enableBgChange 			= false,					-- 背景を切り替えていいか
		is_timeUp					= false,					-- タイムアウトしたか
		is_focusOpenPanel 			= false,					--　フォーカスしたパネルが開いたか
		cursorMoveFlag 				= false,					--　カーソルを動かしたか
		playGenreVoiceFlag 			= false,					-- ジャンル板にフォーカス時に再生するボイスフラグ
		is_courseBackFlag 			= false,					--　難易度選択画面から戻ってきたか
		is_shopBackFlag 			= false,					-- ショップシーケンスから戻ってきたか
		is_timeUpOpenAnimataionEnd 	= false,					--　タイムアウト時のフォルダを開くアニメーションが終わったか
		is_inputEnable 				= false,					-- 入力受付可能フラグ
		is_firstInputDon			= false,					-- 一回でもドン入力を入れたか
		is_firstInputKatsu			= false,					-- 一回でもカツ入力を入れたか
		is_firstOpenGenre			= false,					-- ジャンルフォルダを初めて開いたか
		is_firstSelectVoice 		= false,					-- 遷移直後のボイスを鳴らしたか
		is_timeUpSelectShop 		= false,					--　購入対象楽曲でタイムアウトしたか
		is_endFlag 					= false,					-- 楽曲を選択したか
		is_timeUpEnable				= true,						--　タイムアウト受付フラグ
		is_QRcodeSequence			= false,					-- QRコードシーケンスの開始
		is_folderOpenNow			= false,					-- 今現在フォルダを開いているかどうか
		
		-- 板に応じた曲indexのオフセット。並びは753102468
		-- 上へ移動する＝下の曲を選択する時は2が中央
		-- 下へ移動する＝上の曲を選択する時は1が中央
		songPanelIndexOffset = 
		{
			{0,-1,1,-2,2,-3,3,-4}, {1,0,2,-1,3,-2,4,-3}, {0,-1,1,-2,2,-3,3,-4}
		},
		
		Init = function(this)

			-- 画面に表示するパネルクラスを作成する
			this.State_.func_["Begin"] = function()
				-- 各種パーツ読み込み
				
				for idx = 1, this.kPanelNum do
					this.multi_board_[idx] = {}
					this.multi_board_[idx] = AISongSelectMultiBoard.New(Lumen.GetMovieClip("main/kanban",true))

					this.multi_board_[idx]:LoadMovieGenreBoard(idx)
					this.multi_board_[idx]:LoadMovieSongBoard(idx)
				end
				
				this.State_:SetState("Loading")
			end
			
			--　各種値のイニシャライズ
			this.State_.func_["Loading"] = function()
				if (Lumen.IsLoadMovieFinish() == true) then
					-- ムービークリップ取得
					this.mc_main = Lumen.GetMovieClip("main",true)
					this.mc_Kanban = Lumen.GetMovieClip("main/kanban",true)		-- ルートのMCからツリーを全部書く
					
					for idx = 1, this.kPanelNum do
						this.multi_board_[idx]:SetupGenreBoard(idx)
						this.multi_board_[idx]:SetupSongBoard(idx)
						
						this.multi_board_[idx]:SetupGenreDetail(idx)
						this.multi_board_[idx]:SetupSongDetail(idx)
					end
					
					this.panelNum = #tbl_genreName
					
					-- デフォルトフォーカスの位置を決める
					this:SetDefaultFocusGenre()
					
					this:SetSongDataAll()
					this:SetSongIcon()
					this:SetSongPanelDispOpenType(this:GetPanelData(this.currentSongIndex), false)
					
					this.mc_Kanban:GotoAndStop("wait")
					this:GetGenreKanbanMc(this.kSelectNumber):GotoAndPlay("select_on")
					this:SetFocusOpenPanel(true)
					
					this:UpdateSongChoise(this.currentSongIndex)
					this:SetEnableBgChangeFlag(true)
					
					if (this:GetFirstInputKatsu() == false and this:GetMoveFlag() == false and this.is_firstSelectVoice == false) then
						TSound:Play("voice_senkuoku_v12a", "senkyoku_loop")
						this.is_firstSelectVoice = true
					end
					
					-- AI曲選択BGM
					TSound:PlayBGM("bgm_aisenkyoku_v12g")

					this.State_:SetState("StartWait")
				end
			end
			
			-- 再度シーケンスが戻った時用
			this.State_.func_["ReLoading"] = function()
				if (Lumen.IsLoadMovieFinish() == true) then
					
					this.songPanelIndexOffsetType = 1
					this.scrollDirection          = 0
					this.kSelectNumber            = 1
					this.playGenreVoiceFlag       = false
					this.is_timeUpSelectShop      = false
					
					this:SetSongPanelDispOpenType(this:GetPanelData(this.currentSongIndex), false)
					this:SetSongDataAll()
					
					if (this:GetCourseBackFlag() == true) then
					
						if (this.scrollDirection >= 0) then
							this:GetGenreKanbanMc(this.kSelectNumber):GotoAndPlay("select_on")					
							this:GetSongKanbanMc(this.kSelectNumber):GotoAndPlay("select_on")
						else 
							this:GetGenreKanbanMc(this.kSelectNumber):GotoAndPlay("off")					
							this:GetSongKanbanMc(this.kSelectNumber):GotoAndPlay("off")					
						end
						
					end
					
					this:GetGenreKanbanMc(this.kSelectNumber + 1):GotoAndPlay("off")			
					this:GetSongKanbanMc(this.kSelectNumber + 1):GotoAndPlay("off")
					
					this:SetCourseBackFlag(false)

					data = this:GetPanelData(this.currentSongIndex)
					
					this.State_:SetState("Main")
				end
			end
			
			--　メインシーケンスに入る前のウェイト　
			this.State_.func_["StartWait"] = function()
					
				if(this:waitCnt() == true) then
					
					this.is_setUpAllOk = true
					
					this.State_:SetState("Main")
				end
			end
			
			--　メインシーケンス
			this.State_.func_["Main"] = function()
				--Debug.PrintString(this.scrollDirection)
				data = this:GetPanelData(this.currentSongIndex)
		
				if (this:VoiceStartCount() == true and this.playGenreVoiceFlag == false and this:GetFirstInputKatsu() == true) then
					-- ジャンルフォーカス時のVoice
					TSound:Play("voice_senkuoku_v12a", data.genre_vo_toneId)
					this.playGenreVoiceFlag = true
				end
				
				-- プレイヤーの入力周り
				this:ProcessSkipping()
				this:PlayerInput()
				
				-- フォーカスが切り替わっている間は入力受付を切る
				if (this.mc_Kanban:IsPlay() == true) then
					this:SetInputEnable(false)
				else
					this:SetInputEnable(true)
				end
				
				-- 一曲目の設定
				this:ProcKanbanWaitCountToSelectOn()
				
				this:SetSongPanelDispOpenType(data, false)	
				this:StayCount()
				
				if (this:IconChangeCount() == true) then
					this:UpdateSongIcon()
				end
			end
			
			-- フォーカスを切り替えた時
			this.State_.func_["Scroll"] = function()
				this.openPanelWaitCount = this.kopenPanelWaitCount
				this.State_:SetState("Main")
			end
			
			--　フォルダを開いた時
			this.State_.func_["OpenFolderState"] = function()
				
				this.is_folderOpenNow = true
				
				-- 二曲目以降の時に前回選んだ楽曲にフォーカスを合わせる
				if (this.is_QRcodeSequence == true) then
					this.is_QRcodeSequence = false
					this:SetQRCodeFocusSong()
				elseif (data.genre_id == this.selected_last_genre) then 
					this:SetDefaultFocusSong() 
				end
				
				TSound:StopBank("voice_senkuoku_v12a")
				
				-- 特定の動かしたフォーカスの方向の時オフセットを掛ける
				if (this.scrollDirection < 0 and this.is_timeUpSelectShop ~= true) then
					this.openOffset = 0
					this.openOffset = this.openOffset + 1
				end
				
				-- フォルダを開いた時にフォーカスしていた板のアニメーションフレームが指定の値まで進んだら
				if (this:GetGenreKanbanMc(this.kSelectNumber + this.openOffset).current_frame == this.kOpenFolderChangeFrame) then
					
					--　板に曲を設定する
					this:SetSongDataAll()
					
					data = this:GetPanelData(this.currentSongIndex)
					this:SetSongPanelDispOpenType(data, true)
				end
				
				-- フォルダを開いた時のアニメーションが全て終了したら
				if (this.mc_Kanban:IsPlay() == false and this:GetSongKanbanMc(this.kSelectNumber + this.openOffset):IsPlay() == false) then
					this:SetTimeUpOpenAnimataionEnd(true)
					this:GetSongKanbanMc(this.kSelectNumber):GotoAndPlay("on")
					
					this:SetPlaySoundFlag(true)

					this.is_firstOpenGenre = true
					this.scrollDirection   = 1
					this.is_timeUpEnable   = true
					
					this:UpdateSongChoise(this.currentSongIndex)
					
					--　タイムアウトでフォルダを開いたらTimeupに遷移
					if (this.is_timeUp == true) then 
						this.State_:SetState("Timeup")
					else
						
						-- 購入対象フラグを全て戻す
						for idx = 1, #tbl_is_lock_ do
							tbl_is_lock_[idx] = false
						end

						this.is_timeUpEnable = true
						
						this.State_:SetState("Main")
					end
				end
			end
			
			--　フォルダをとじた時
			this.State_.func_["CloseFolderState"] = function()
				Debug.PrintString("CloseFolderState")
				
				this.is_folderOpenNow = false
				this.songPanelIndexOffsetType = this.kScrollOffsetTypeWait
				
				-- 特定の動かしたフォーカスの方向の時オフセットを掛ける　
				if (this.scrollDirection < 0) then
					this.openOffset = 0
					this.openOffset = this.openOffset + 1
				end
				
				-- フォルダをとじた時にフォーカスしていた板のアニメーションフレームが指定の値まで進んだら
				if (this:GetSongKanbanMc(this.kSelectNumber + this.openOffset).current_frame >= this.kCloseFolderChangeFrame) then
					this.currentSongIndex = this:GetGenreIndex(genreIdStr)
					this:SetSongDataAll() 
				end
				
				-- フォルダを閉じた時のアニメーションが全て終了したら
				if (this.mc_Kanban:IsPlay() == false) then
					this:SetSongDataAll()
					this:GetGenreKanbanMc(this.kSelectNumber):GotoAndPlay("on")

					this.State_:SetState("ReLoading") 
				end

			end
			
			--　タイムアウト時
			this.State_.func_["Timeup"] = function()
				
				if (this.mc_Kanban:IsPlay() == false) then
					if (data.panel_genre_id == "back") then
						this:MoveCursor(1, true, true)
					elseif (data.song_isForShop == true and data.song_isOpen == false) then
						this:MoveCursor(1, true, true)
					elseif (data.panel_genre_id == "song" and data.song_isForShop == false or data.song_isOpen == true) then
						-- ＳＥ「大どん（中央）」
						TSound:Play("se_common_v12a","don_big")
						this.State_:SetState("End")
						
					else
						this:SetTimeUpOpenFolder() 
						this.State_:SetState("Main")
					end
				end
			end
			
			--　終了時
			this.State_.func_["End"] = function()
				
				data = this:GetPanelData(this.currentSongIndex)

				songId = data.song_uniqueId
				songIdstr = data.song_id
				
				selectedSongData = data  	-- 最終的に選択した曲情報をグローバルに格納
				
				this:SetGlobalGenreId()

				this.openOffset = 0
				
				-- 特定の動かしたフォーカスの方向の時オフセットを掛ける
				if (this.scrollDirection < 0) then
					this.openOffset = this.openOffset + 1
				end
				
				--　とじるを選んだ時
				if (songIdstr == "back") then
					this:SetResultType(this.kResultCanseled)
					this:PlaySeCancel()
					
					this:GetSongKanbanMc(this.kSelectNumber + this.openOffset):GotoAndPlay("return")	
					this:GetGenreKanbanMc(this.kSelectNumber):GotoAndPlay("return")
				
					if (this.scrollDirection < 0) then
						this.mc_Kanban:GotoAndPlay("return2")
						else this.mc_Kanban:GotoAndPlay("return")
					end
				
				elseif (data.song_isForShop == true and this.is_timeUp == true and data.song_isOpen == true) then
				
					-- タイムアップ時にユーザーが開放済みなら通常遷移させる
					this:DecideSongPanelAnimation()
					
				elseif (data.song_isForShop == true and data.song_isOpen == false and is_CardPlayer == true) then
					
					-- 既にネットワークエラーになっている場合はビープ音を鳴らしてメインへ
					if (is_networkError == true) then
					
						this:PlaySeBeep()
						this:SetResultType(this.kResultRunning)
						this.State_:SetState("Main") 
					else
						-- ショップに遷移する場合はドンを鳴らす
						this:PlaySeDon()
						this:SetResultType(this.kResultShop)					
					end
				
				elseif (data.song_isForShop == true and data.song_isOpen == false and is_CardPlayer ~= true) then
					
					-- 片方のカードの人間が解放していない場合で、もう片方のコインが選択した場合(何もしない)
					this:PlaySeBeep()
					this:SetResultType(this.kResultRunning)
					this.State_:SetState("Main") 
					
				else
					this:DecideSongPanelAnimation()
				end
				
				if (data.genre_id == "howto") then
					is_SelectTutorial = true
				end
			end
		end,
		
	-- ここまでInit
		
		-- セットアップが完了してメインに遷移するまでのカウント
		waitCnt = function(this)
			this.start_input_cnt = this.start_input_cnt +1
						
			if (this.start_input_cnt >= this.wait_input_cnt) then
				this.start_input_cnt = 0
				return true
			else return false
			end
		end,
		
		--　ステートの更新
		Update = function(this)
			this.State_:Update()
		end,
		
	-- ここまでUpdate
		
		--　再度シーケンスが戻った時用
		ReStartSongSelect = function(this)
			this:GetGenreKanbanMc(this.kSelectNumber):GotoAndPlay("return")					
			this.State_:SetState("ReLoading")
		end,
		
		--　ショップシーケンスから戻った時用
		BackShopSongselect = function(this)
			this.State_:SetState("Main")
		end,
		
		--　フォルダを開いた時
		OpenGenreFolder = function(this)
			
			--　一度でもフォルダを開いているなら
			if (this.is_firstOpenGenre == true) then
				--　閉じた時のインデックスが残っているなら
				if (this:GetCloseGenreIndex() ~= nil) then
					this.currentSongIndex = this:GetCloseGenreIndex() + 1
				end
			end
			
			--　タイムアウト且つ購入対象楽曲の場合
			if (this.is_timeUp == true and data.song_isForShop == true) then
				this:SetCurrentSongIndex(this:GetFirstSongIndex(true))
			end

			this.State_:SetState("OpenFolderState")
		end,
		
		--　フォルダを閉じた時
		CloseGenreFolder = function(this)
		-- ステート処理
			this:SetCloseGenreIndex()
			this.State_:SetState("CloseFolderState")
		end,
		
		--　全体のパネルの数を更新
		UpdatePanelNum = function(this, selectedSongNum, OpenGenreNum)
			this.panelNum = #tbl_genreName + selectedSongNum + backPanelNum - OpenGenreNum  --インサートした戻る看板の数を足す
		end,
		
		--　プレイヤーの入力
		PlayerInput = function(this)
		
			-- キー入力
			if ((this:CheckInput() == this.INPUT_1P_DECIDE or this:CheckInput() == this.INPUT_2P_DECIDE) or this.is_timeUp == true) then
				-- 面
				-- ジャンルパネル選択
				-- 選択時の処理
				
				this:SetFirstInputDon(true)
				
				this:ResetSkippingVariables()
				
				-- 遊び方説明にフォーカスして選択した時の処理
				if (data.genre_uniqueId >= 9999) then
					is_SelectTutorial = true
					this.State_:SetState("End")
					return
				end
				
				-- フォルダを既にオープンしていて、曲板にフォーカスして選択した時の処理
				if (data.panel_genre_id == "song") then
					this:SetOpenFolder(false)
					this.State_:SetState("End")
					return
				end
				
				if (data.song_id == "back") then
					if (this.is_timeUp == true) then
						this.State_:SetState("Timeup")
						return
					end
				end
				
				-- フォルダにフォーカスして選択した時の処理
				if (this:IsFolderOpen() == true) then
					this:SelectGenreFolder()
				end
				
				this.State_:SetState("End")
			
			-- QRコードをタッチした時
			elseif (this.is_QRcodeSequence == true) then
				
				this:ResetSkippingVariables()
				
				-- 該当のフォルダを既にオープンしていた時
				if (genreIdStr == this.QRgenreIndexStr and this.is_folderOpenNow == true) then
					this.is_QRcodeSequence = false
					this:SetQRCodeFocusSong()
					this:SetSongDataAll()
					
					this.scrollDirection = 1
					this.mc_Kanban:GotoAndStop("wait")
					
					this:UpdateSongChoise(this.currentSongIndex)
					
					this:SetEnableBgChangeFlag(true)
					
					return
				end

				if (this:IsFolderOpen() == true) then	
					this:SelectGenreFolder()
				end

			-- 先にスキップ入力確認
			elseif (this:IsSkippingTriggeredRight() == true and this:GetPanelNum() > 1) then
				Debug.PrintString("SkippingTriggeredRight")
				this:SkipMoveDonAnimation()
				this:MoveCursor(7, true, false)
			elseif (this:IsSkippingTriggeredLeft() == true and this:GetPanelNum() > 1) then
				Debug.PrintString("SkippingTriggeredLeft")
				this:SkipMoveDonAnimation()				
				this:MoveCursor(-7, true, false)
			elseif (this:IsIgnoreKatsu() == false) then
				if (this:CheckInput() == this.INPUT_1P_RIGHT or this:CheckInput() == this.INPUT_2P_RIGHT) then
					if (this:GetPanelNum() > 1) then 
						Debug.PrintString("TriggeredRight")
						-- 右ふち
						-- ジャンルパネルのフォーカスを右へ移動
						this:PlaySeKatsu()				
						this:MoveCursor(1, true, false)
					end
				elseif (this:CheckInput() == this.INPUT_1P_LEFT or this:CheckInput() == this.INPUT_2P_LEFT) then
					if (this:GetPanelNum() > 1) then 
						Debug.PrintString("TriggeredLeft")
						-- 左ふち
						-- 曲パネルのフォーカスを左へ移動
						this:PlaySeKatsu()								
						this:MoveCursor(-1, true, false)
					end
				end
			end

		end,
		
		-- 左右カツ入力
		MoveCursor = function(this, direction, isFirst, timeUp)
		
			if (this:GetPanelNum() <= 1) then
				return
			end
			
			this:SetFirstInputKatsu(true)
			this:SetMoveFlag(true)
			this:SetEnableBgChangeFlag(true)
			
			-- 曲名称を呼んでいるボイスを停止
			TSound:StopBank("voice_senkuoku_v12a")
			this.playGenreVoiceFlag = false
			
			this.scrollDirection = direction;
					
			-- 移動方向によって提灯と曲のindexの対応テーブルを切り替え、アニメさせる
			if (this.scrollDirection < 0) then
				this.songPanelIndexOffsetType = this.kScrollOffsetTypeMoveU
				this.mc_Kanban:GotoAndPlay(this.tbl_SongKanbanMoveLabel[this.kKanbanMoveUp])

			else 
				this.songPanelIndexOffsetType = this.kScrollOffsetTypeMoveD
				this.mc_Kanban:GotoAndPlay(this.tbl_SongKanbanMoveLabel[this.kKanbanMoveDown])
			end
			
			selectIndex = this:ValidateSongPanelIndex(this.currentSongIndex + direction)
			this:ChangeSong(selectIndex)
			
			offsetTable = {}
			offsetTable = this.songPanelIndexOffset[this.songPanelIndexOffsetType]
			
			panelNum = this:GetSongPanelNum()

			isVisible = false
			
			for i = 1, #offsetTable do
				
				isVisible = false;
				if (panelNum >= (#offsetTable-1) or i < panelNum) then
					isVisible = true
				else 
					-- 下へ移動する（上に一個足す）
					if (this.songPanelIndexOffsetType == this.kScrollOffsetTypeMoveD) then
					
						if ((panelNum % 2 == 0 and i == panelNum) or (panelNum % 2 ~= 0 and i == panelNum+1)) then
							isVisible = true
						end
						
					-- 上へ移動する（下に一個足す）
					else 
						if ((panelNum % 2 == 0 and i == panelNum) or (panelNum % 2 ~= 0 and i == panelNum+1)) then
							isVisible = true
						end
					end
				end
				
				if (isVisible) then
					if (isFirst) then
						if (i == 1 and this:GetFocusOpenPanel() == true) then
							str = (this.scrollDirection < 0) and "select_off" or "off"

								this:GetGenreKanbanMc(i):GotoAndPlay(str)
								this:GetSongKanbanMc(i):GotoAndPlay(str)
						elseif (i == 2 and this:GetFocusOpenPanel() == true) then
							str = (this.scrollDirection < 0) and "off" or "select_off"

								this:GetGenreKanbanMc(i):GotoAndPlay(str)
								this:GetSongKanbanMc(i):GotoAndPlay(str)
						end
					end
				end
			end
			
			this:SetFocusOpenPanel(false) 
			this:VoiceStartCountReset()
			
			this.start_cnt = 0
			this.stay_cnt = 0
			
			this:SetSongDataAll()
			
			if (timeUp ~= true) then
				this.State_:SetState("Scroll")
			else return
			end
		end,
		
		-- フォルダを選択した時
		SelectGenreFolder = function(this)
			Debug.PrintString("SelectGenreFolder")
			this:PlaySeDon()
			
			this.is_timeUpEnable = false
			genreSelectFlag      = true

			genreId              = data.genre_uniqueId
			genreIdStr           = data.genre_id
			panelIdstr           = data.panel_genre_id
			
			this:SetOpenFolder(true)
			
			this.kSelectNumber = 1
			this.openOffset    = 0
			
			-- 強制的に板を動かした場合方向を決定する必要がある
			if (this.is_timeUpSelectShop == true or this.is_QRcodeSequence == true) then
				this.scrollDirection = 1
				this:ClosePanelOutside()
			end
			
			if (this.scrollDirection < 0) then
				this.openOffset = this.openOffset + 1
			end
			
			this:GetGenreKanbanMc(this.kSelectNumber + this.openOffset):GotoAndPlay("genre_deceide")
			
			this:GetSongKanbanMc(this.kSelectNumber):GotoAndPlay("genre_deceide")
			
			if (this.scrollDirection < 0) then
				this.mc_Kanban:GotoAndPlay("genre_deceide2")
			else
				this.mc_Kanban:GotoAndPlay("genre_deceide") 
			end
			
			this:SetCourseBackFlag(false)

			this.songPanelIndexOffsetType = 1
			
			this:DecideDonAnimation()

		end,
		
		--　全体のパネルの数
		GetPanelNum = function(this)
			return this.panelNum
		end,
		
		--　インデックスで指定したパネルの情報を取得する
		GetPanelData = function(this, songIndex)
			--songData通しのIndex	
			index = this:ValidateSongPanelIndex(songIndex)
			
			if (index <= 0) then
				index = this:GetPanelNum()
			end
				
			return genreData[index]
			
		end,
		
		--　決定時のアニメーション
		DecideSongPanelAnimation = function (this)
			
			if (this.is_endFlag == false) then 
				this:PlaySeDon()
				this:DecideDonAnimation()
				this:GetSongKanbanMc(this.kSelectNumber + this.openOffset):GotoAndPlay("song_decide")
				this.is_endFlag = true
			end
			
			if (this:GetSongKanbanMc(this.kSelectNumber + this.openOffset):IsPlay() == false) then
				this:SetResultType(this.kResultDecided)
				this.is_endFlag = false
			end

		end,
		
		-- スキップ時のどんアニメーション
		SkipMoveDonAnimation = function(this)
			TSound:Play("se_senkyoku_v12a","skip_songs")
			Don.SetNonLoopAnimation(0,"combo",true)
			Don.SetLoopAnimation(0,"result_clear_loop",true)
		end,
		
		-- フォルダ・曲決定時のどんアニメーション
		DecideDonAnimation = function(this)
			Don.SetNonLoopAnimation(0,"full_combo",true)
			Don.SetLoopAnimation(0,"result_clear_loop",true)
		end,
		
		-- 曲の数
		GetSongPanelNum = function(this)
			offsetTable = {}
			offsetTable = this.songPanelIndexOffset[this.songPanelIndexOffsetType]
			return (this:GetPanelNum() < #offsetTable) and this:GetPanelNum() or #offsetTable
		end,

		-- 曲を変更する
		ChangeSong = function(this, index)
			this:UpdateSongChoise(index)
		end,
		
		-- folderData通しのIndex
		ValidateSongPanelIndex = function(this, songPanelIndex)
		
			panelNum = this:GetPanelNum()
			index = songPanelIndex
			
			if (panelNum <= 1) then
				return 0
			end
			
			if (index >= 0) then
				index = index % panelNum
			else 
				index = ((math.ceil(5/panelNum)+2)*panelNum + index)
				index = math.fmod(index ,panelNum)
			end

			return index
		end,
		
		--すべての板に曲名を設定する.
		SetSongDataAll = function(this)
			Debug.PrintString("SetSongDataAll")

			local offsetTable = {}
			offsetTable = this.songPanelIndexOffset[this.songPanelIndexOffsetType]

			for idx = 1, #offsetTable do
				SongData = this:GetPanelData(this.currentSongIndex + offsetTable[idx])
				
				if (SongData.genre_uniqueId >= SongGenre.kPops) then 
					this.multi_board_[idx]:SetFolderData(idx, SongData)
				else this.multi_board_[idx]:SetSongData(idx, SongData, SongAttributeData)
				end
				
				this:SetVisibleAllPanel(idx, SongData)
				
			end
			
		end,
		
		--すべての曲板のアイコンを初期化
		SetSongIcon = function(this)
			Debug.PrintString("SetSongIcon")

			local offsetTable = {}
			offsetTable = this.songPanelIndexOffset[this.songPanelIndexOffsetType]

			for idx = 1, #offsetTable do
				SongData = this:GetPanelData(this.currentSongIndex + offsetTable[idx])
				
				if (SongData.genre_uniqueId < SongGenre.kPops) then 
					this.multi_board_[idx]:SetSongIcon(idx, SongData)
				end
			end
		end,
		
		--鍵アイコン情報&必要ドンメダルの情報を更新する
		SetTokenInformation = function(this)
			Debug.PrintString("SetSongIcon")

			local offsetTable = {}
			offsetTable = this.songPanelIndexOffset[this.songPanelIndexOffsetType]

			for idx = 1, #offsetTable do
				SongData = this:GetPanelData(this.currentSongIndex + offsetTable[idx])
				
				if (SongData.genre_uniqueId < SongGenre.kPops) then 
					this.multi_board_[idx]:UpdateTokenInformation(idx, SongData)
				end
			end
		end,

		--すべての曲板のアイコンと必要などんメダルを切り替える
		UpdateSongIcon = function(this)
			Debug.PrintString("UpdateSongIcon")
			
			local offsetTable = {}
			offsetTable = this.songPanelIndexOffset[this.songPanelIndexOffsetType]

			for idx = 1, #offsetTable do
				SongData = this:GetPanelData(this.currentSongIndex + offsetTable[idx])
				
				if (SongData.genre_uniqueId < SongGenre.kPops) then 
					this.multi_board_[idx]:UpdateSongIcon(idx, SongData)
				end
			end
		end,
		
		-- フォルダをとじた時の最後のIndexを保存する
		SetCloseGenreIndex = function(this)
			this.save_current_index[genreIdStr] = this.currentSongIndex			
		end,
		
		-- フォルダをとじた時の最後のIndexを取得する
		GetCloseGenreIndex = function(this)
			return this.save_current_index[genreIdStr]
		end,

		-- 曲の選択状態を更新
		UpdateSongChoise = function(this, songIndex)
			-- 曲の再生
			this:SetPlaySoundFlag(true)
			
			this.currentSongIndex = songIndex
			data = this:GetPanelData(songIndex)
			
			this:SetGlobalGenreId()
			
			if (data) then
				songId = data.song_uniqueId
				--genreId = data.genre_uniqueId
				if (data.genre_uniqueId >= SongGenre.kPops) then 
					--genreIdStr = data.genre_id
					genreIdStrForBg = data.genre_id
				else genreIdStrForBg = genreIdStr
				end
			end
		end,
		
		-- 曲看板データmc
		GetSongKanbanMc = function(this, panel)
			return this.multi_board_[panel].mc_songBoard[panel].main.board
		end,
		
		-- ジャンル看板データmc
		GetGenreKanbanMc = function(this, panel)
			return this.multi_board_[panel].mc_genreBoard[panel].main.board
		end,
		
		--　フォルダを開いたか
		IsFolderOpen = function(this)
		
			if (data.panel_genre_id == "genre" or data.panel_genre_id == "event" ) then			 return true
			elseif (data.panel_genre_id == "favorite" or data.panel_genre_id == "recent" ) 	then return true
			elseif (data.panel_genre_id == "custom") 										then return true
			elseif (data.panel_genre_id == "shop") 											then return true
			elseif (data.panel_genre_id == "dani") 											then return true

			else return false
			end
		end,
	
		-- 板の表示を制御する
		SetVisibleAllPanel = function(this, idx, SongData)
			this.multi_board_[idx]:SetVisiblePanel(idx, SongData)
		end,
		
		-- フォーカス時に楽曲名とサブ表記を元に戻す
		SetSongPanelDispOpenType = function (this, songData, firstFlag)
		
			this.openOffset = 0
	
			if (this.scrollDirection < 0) then
				this.openOffset = this.openOffset + 1
			end
			
			if (this.multi_board_[this.kSelectNumber + this.openOffset].mc_songBoard[this.kSelectNumber + this.openOffset].main.board.current_frame == 20) then
				this.multi_board_[this.kSelectNumber + this.openOffset]:SetOpenTypeDispData(this.kSelectNumber + this.openOffset, songData)
			elseif (firstFlag == true) then
				this.multi_board_[this.kSelectNumber]:SetOpenTypeDispData(this.kSelectNumber, songData)
			end
		end,
		
		-- フォーカスしている看板を開く
		ProcKanbanWaitCountToSelectOn = function(this)
		
			this.openOffset = 0
		
			if (this.scrollDirection < 0) then
				this.openOffset = this.openOffset + 1
			end
			
			-- -- パネル制御
			if (this.openPanelWaitCount > 0) then
			
				this.openPanelWaitCount = this.openPanelWaitCount -1
				
				if (this.openPanelWaitCount <= 0) then
					this:SetFocusOpenPanel(true)
					--MoveFlag = true
					if (data.genre_uniqueId >= 0) then
						this.multi_board_[this.kSelectNumber + this.openOffset].mc_genreBoard[this.kSelectNumber + this.openOffset].main.board:GotoAndPlay("select_on")
					else
						this.multi_board_[this.kSelectNumber + this.openOffset].mc_songBoard[this.kSelectNumber + this.openOffset].main.board:GotoAndPlay("select_on")
					end
				end				
			end
		end,
		
		--　C++側で参照する変数に選択したジャンルの情報を格納する
		SetGlobalGenreId = function(this)
			
			if (genreIdStr 	   == "pops") 		then genreIdEnum = this.kPops
			elseif (genreIdStr == "anime") 		then genreIdEnum = this.kAnime
			elseif (genreIdStr == "kids") 		then genreIdEnum = this.kKids
			elseif (genreIdStr == "vocaloid") 	then genreIdEnum = this.kVocalo
			elseif (genreIdStr == "game")		then genreIdEnum = this.kGame
			elseif (genreIdStr == "namco") 		then genreIdEnum = this.kNamco
			end
			
		end,
		
		-- ジャンルのid(int)からid(str)を返す
		SearchGenreId = function(this, index)
			
			if (index 	  == 0) 	then return  "pops"
			elseif (index == 1)		then return  "anime"
			elseif (index == 2)		then return  "kids"
			elseif (index == 3) 	then return  "vocaloid"
			elseif (index == 4)		then return  "game"
			elseif (index == 5)		then return  "namco"
			end

		end,
		
		-- 実行状態を取得する
		GetResult = function(this)
			return this.resultType
		end,
		
		-- フォルダの開閉状態を取得する
		GetOpenFolder = function(this)
			return this.is_openFolder
		end,
		
		-- フォルダの開閉状態をセットする
		SetOpenFolder = function(this, setFlag)
			this.is_openFolder = setFlag
		end,

		-- タイムアップ時にフォルダーを開くアニメーションが終わったかを取得
		GetTimeUpOpenAnimataionEnd = function(this)
			return this.is_timeUpOpenAnimataionEnd
		end,
		
		-- タイムアップ時にフォルダーを開くアニメーションが終わったかをセット
		SetTimeUpOpenAnimataionEnd = function(this, setFlag)
			this.is_timeUpOpenAnimataionEnd = setFlag
		end,

		-- 実行状態をセットする
		SetResultType = function(this, type)
			this.resultType = type
		end,
		
		-- 背景変更フラグを取得する
		GetEnableBgChangeFlag = function(this)
			return this.is_enableBgChange
		end,

		-- 背景変更フラグをセットする
		SetEnableBgChangeFlag = function(this, setFlag)
			this.is_enableBgChange = setFlag
		end,
		
		-- カーソル移動フラグを取得する
		GetMoveFlag = function(this)
			return this.cursorMoveFlag
		end,

		-- カーソル移動フラグをセットする
		SetMoveFlag = function(this, setFlag)
			this.cursorMoveFlag = setFlag
		end,
		
		-- 難易度選択から戻ったのかフラグを取得する
		GetCourseBackFlag = function(this)
			return this.is_courseBackFlag
		end,
		
		-- 難易度選択から戻ったのかフラグを設定する
		SetCourseBackFlag = function(this, setFlag)
			this.is_courseBackFlag = setFlag
		end,
		
		-- ショップ機能から戻ったのかフラグを取得する
		GetShopBackFlag = function(this)
			return this.is_shopBackFlag
		end,
		
		-- ショップ機能から戻ったのかフラグを設定する
		SetShopBackFlag = function(this, setFlag)
			this.is_shopBackFlag = setFlag
		end,

		-- カレントインデックスをセットする
		SetCurrentSongIndex = function (this, index)
			this.currentSongIndex = index
		end,
		
		-- 指定のジャンルIDを持つGenreDataのIndexを取得
		GetGenreIndex = function(this, genreId)
			for idx = 1,  this.panelNum do
				if (genreData[idx].genre_id == genreId) then
					return idx
				end
			end
			return nil
		end,
		
		-- 指定の楽曲IDを持つGenreDataのIndexを取得
		GetSongIndex = function(this, songId)
			for idx = 1,  this.panelNum do 
				if (genreData[idx].song_id == songId) then
					return idx
				end
			end
		end,
		
		-- 楽曲のUniqueIdから、デフォルトのジャンル(int:id)を取得
		GetDefaultGenreByUniqueId = function(this, song_uniqueId)
		
			local QRSonginfo = MusicInfo.create(song_uniqueId)
			
			if (QRSonginfo.id == "") then
				return nil
			end
			
			local QRgenre = QRSonginfo.genre

			return QRgenre
		end,
		
		-- 楽曲の初期フォーカス位置を決める
		SetDefaultFocusSong = function(this)
		
			local defaultSonginfo = MusicInfo.create(user_setting_data_.songUniqueId)
			local song_id = defaultSonginfo.id
			if (playSongCount >= 2) then
				this.currentSongIndex = this:GetSongIndex(song_id)
			end
		end,
		
		-- QRコードで読み取った楽曲のフォーカス位置を決める
		SetQRCodeFocusSong = function(this)
		
			local QRSonginfo = MusicInfo.create(this.QRSelectSongUniqueId)
			local song_id = QRSonginfo.id
			
			this.currentSongIndex = this:GetSongIndex(song_id)
		end,

		-- フォルダの初期フォーカス位置を決める
		SetDefaultFocusGenre = function(this)
			
			this.selected_last_genre = user_setting_data_.genreFolderStr
			
			if (playSongCount >= 2) then
				this.currentSongIndex = this:GetGenreIndex(this.selected_last_genre)
				return
			end

			-- 楽曲お試し・獲得の曲がある
			local QRSongTrialUID = QR.GetTrialSongUID()
			if(QRSongTrialUID > 0) then
				local QRgenre_id = this:GetDefaultGenreByUniqueId(QRSongTrialUID)
				if (QRgenre_id ~= nil) then
					this.selected_last_genre = this:SearchGenreId(QRgenre_id)
					this.currentSongIndex = this:GetGenreIndex(this.selected_last_genre)
					return
				end
			end

			-- カスタムフォルダがある
			if (is_customFolder == true) then
				this.selected_last_genre = "custom"
				this.currentSongIndex = this:GetGenreIndex(this.selected_last_genre)
				return
			end

			if (is_aiPlayerTutorial == true) then
			
				local firstIndex = this:GetGenreIndex("pops")
				
				if (firstIndex == nil) then
					this.currentSongIndex = this:GetFirstGenreIndex()
				else this.currentSongIndex = firstIndex
				end
				
				return
			end
		end,
		
		-- QRコードで取得した曲のデフォルトジャンルのフォーカス位置を決める
		SetQRCodeFocusGenre = function(this, song_uniqueId)
			
			local QRgenre_id = this:GetDefaultGenreByUniqueId(song_uniqueId)
			
			if (QRgenre_id == nil) then
				return false
			end
			
			this.QRgenreIndexStr = this:SearchGenreId(QRgenre_id)
			
			if (this:GetGenreIndex(this.QRgenreIndexStr) ~= nil) then
				this.currentSongIndex = this:GetGenreIndex(this.QRgenreIndexStr)
				this:UpdateSongChoise(this.currentSongIndex)
				this:SetEnableBgChangeFlag(true)
				return true
			else
				-- 開いているフォルダが該当のフォルダの場合
				if (genreIdStr == this.QRgenreIndexStr and this.is_folderOpenNow == true) then
					return true
				end
			end
			
			return false
		end,

		-- 楽曲が入っている最初のIndexを取得
		GetFirstSongIndex = function(this, releaseCheck)
		
			if (releaseCheck == false) then
				for idx = 1,  #genreData do
					if (genreData[idx].song_uniqueId >= 0 and genreData[idx].song_uniqueId < 99999) then
						return idx
					end
				end
			
			-- 開放済みかどうかの判定を含める
			elseif (releaseCheck == true) then
				for idx = 1,  #genreData do
					if (genreData[idx].song_uniqueId >= 0 and genreData[idx].song_uniqueId < 99999) then
						if (genreData[idx].song_isOpen == true) then
							return idx						
						end
					end
				end
			end
		end,
		
		-- フォルダが入っている最初のIndexを取得
		GetFirstGenreIndex = function(this)
			for idx = 1,  #genreData do
				if (genreData[idx].panel_genre_id == "genre" and genreData[idx].song_uniqueId < 99999 and genreData[idx].genre_id ~= "howto") then
					return idx
				end
			end
			
			-- 通常のグランドジャンルが見つからない場合は、イベントフォルダの中から探す
			for idx = 1,  #genreData do
				if (genreData[idx].panel_genre_id == "event" and genreData[idx].song_uniqueId < 99999 and genreData[idx].genre_id ~= "howto") then
					return idx
				end
			end
		end,
		
		-- アイコンを切り替えるタイミングをカウント
		IconChangeCount = function(this)
		
			this.start_icon_change_cnt = this.start_icon_change_cnt +1
			
			if (this.start_icon_change_cnt >= this.wait_icon_change_cnt) then
				this.start_icon_change_cnt = 0
				return true
			else return false
			end
		end,
		

		-- フォーカス位置に留まっているフレームが一定値を越えたらフラグが建つ
		StayCount = function(this)
		
			this.stay_cnt = this.stay_cnt +1
			
			if (this.stay_cnt >= this.wait_stay_cnt) then
				this:SetMoveFlag(false)
				this.stay_cnt = 0
			end
		end,
		
		-- フォーカスしたパネルが開いたかどうかのフラグを取得する
		GetFocusOpenPanel = function(this)
			return this.is_focusOpenPanel
		end,
		
		-- フォーカスしたパネルが開いたかどうかのフラグをセットする
		SetFocusOpenPanel = function(this, setFlag)
			this.is_focusOpenPanel = setFlag
		end,

		-- 操作ガイド拡大フラグを取得する
		SetControlGuideFlag = function(this, setFlag)
			this.is_controlGuideZoomFlag = setFlag
		end,
		
		-- 操作ガイド拡大フラグを取得する
		GetControlGuideFlag = function(this)
			return this.is_controlGuideZoomFlag
		end,
		
		-- プレイヤーの入力受付可能かのフラグを取得する
		GetInputEnable = function(this)
			return this.is_inputEnable
		end,
		
		-- プレイヤーの入力受付可能かのフラグをセットする
		SetInputEnable = function(this, setFlag)
			this.is_inputEnable = setFlag
		end,
		
		-- どん入力が1回でもあったかのフラグを取得する
		GetFirstInputDon = function(this)
			return this.is_firstInputDon
		end,
		
		-- どん入力が1回でもあったかのフラグをセットする
		SetFirstInputDon = function(this, setFlag)
			this.is_firstInputDon = setFlag
		end,
		
		-- かつ入力が1回でもあったかのフラグを取得する
		GetFirstInputKatsu = function(this)
			return this.is_firstInputKatsu
		end,
		
		-- かつ入力が1回でもあったかのフラグをセットする
		SetFirstInputKatsu = function(this, setFlag)
			this.is_firstInputKatsu = setFlag
		end,

		-- フォルダ名ボイス再生カウント
		VoiceStartCount = function(this)
		
			this.play_vo_count = this.play_vo_count +1
			
			if (this.play_vo_count >= this.wait_voice_cnt) then
				this.play_vo_count = 0
				return true
			else return false
			
			end
		end,
		
		--　ボイス再生カウントの値をリセット
		VoiceStartCountReset = function(this)
			this.play_vo_count = 0
		end,
		
		-- タイムアップ時の動作開始ウェイト
		WaitCountTimeUpMove = function(this)

			this.timeup_start_cnt = this.timeup_start_cnt + 1
			
			if (this.timeup_start_cnt >= this.wait_timeup_move_cnt) then
				this.timeup_start_cnt = 0
				return true
			else return false
			
			end
		end,
		
		-- 左カーソルで操作を行った際に関係ない板を閉じる
		ClosePanelOutside = function(this)
		
			this:GetGenreKanbanMc(this.kSelectNumber):GotoAndPlay("on")					
			this:GetSongKanbanMc(this.kSelectNumber):GotoAndPlay("on")
				
			this:GetGenreKanbanMc(this.kSelectNumber + 1):GotoAndPlay("off")			
			this:GetSongKanbanMc(this.kSelectNumber + 1):GotoAndPlay("off")
			
		end,
		
		-- 特定のフォルダ・板にフォーカス時に強制的に板を移動させる処理
		SetTimeUpOpenFolder = function(this)
			this:SetCurrentSongIndex(this:GetFirstGenreIndex())
			this:SetSongDataAll()
			this.is_timeUpSelectShop = true
			this:ClosePanelOutside()
		end,
		
		-- プレイヤーの入力情報
		CheckInput = function(this)
			
			if (this:GetInputEnable() == true) then
			
				if(is_joinPlayer[1] == true) then
					-- 1Pの入力
					if (this:GetMoveFlag() == false) then 
						if (Input.GetTrigger(Input.PLAYER1_OK) or Input.GetTrigger(Input.PLAYER1_CANCEL)) then 
						return this.INPUT_1P_DECIDE 
						end
					end
					if (Input.GetTrigger(Input.PLAYER1_LEFT))	then return this.INPUT_1P_LEFT end
					if (Input.GetTrigger(Input.PLAYER1_RIGHT))	then return this.INPUT_1P_RIGHT end
				end
				
				if(is_joinPlayer[2] == true) then
					-- 2Pの入力
					if (this:GetMoveFlag() == false) then 
						if (Input.GetTrigger(Input.PLAYER2_OK) or Input.GetTrigger(Input.PLAYER2_CANCEL)) 
						then return this.INPUT_2P_DECIDE 
						end
					end
					if (Input.GetTrigger(Input.PLAYER2_LEFT))	then return this.INPUT_2P_LEFT end
					if (Input.GetTrigger(Input.PLAYER2_RIGHT))	then return this.INPUT_2P_RIGHT end
				end
			end
		end,
		
		-- どんSEをエントリーによって鳴らす
		PlaySeDon = function(this)
			TSound:Play("se_common_v12a","don_c")
		end,
		
		-- カツSEをエントリーによって鳴らす
		PlaySeKatsu = function(this)
			TSound:Play("se_common_v12a","katsu_c")
		end,

		-- ビープSEをエントリーによって鳴らす		
		PlaySeBeep = function(this)
			TSound:Play("se_common_v12a","beep_c")
		end,
		
		-- キャンセルSEをエントリーによって鳴らす		
		PlaySeCancel = function(this)
			TSound:Play("se_common_v12a","primal_cancel_c")
		end,
		
		-- BGM鳴らし開始フラグをセット
		SetPlaySoundFlag = function(this, setFlag)
			this.playSoundFlag = setFlag
		end,
		
		-- BGM鳴らし開始フラグを取得
		GetPlaySoundFlag = function(this)
			return this.playSoundFlag
		end,
		
		--　タイムアウト時にフラグを建て入り方によって動作を切り替える
		TimeUpBegin = function(this)			
			this.is_timeUp = true
			this.songPanelIndexOffsetType = this.kScrollOffsetTypeWait
				
			if (data.song_isForShop == true) then
				if (data.song_isOpen == false) then
					if (panelIdstr == "shop") then this:SetTimeUpOpenFolder() 
						return
					else					
						this.State_:SetState("Timeup")
					end
				else return
				end
			
			elseif (data.panel_genre_id == "shop") then
				this:SetTimeUpOpenFolder()

			elseif (panelIdstr == "shop" and data.panel_genre_id == "back") then
				this:SetTimeUpOpenFolder()
			end
		end,
		
		--　タイムアウト時に呼ばれる関数
		TimeUpSequence = function(this)
			-- 戻るの場合1回鳴らす回数が多い
			if (songIdstr == "back") then TSound:Play("se_common_v12a","don_big") end
			
			this:OpenGenreFolder()
		end,
		
		--　QRコードタッチによる自動選曲機能開始
		QRCodeSelectBegin = function(this, song_uniqueId)
			
			if (this.mc_Kanban:IsPlay() == true) then
				return
			end
			
			this.QRSelectSongUniqueId = song_uniqueId
			
			if (this:SetQRCodeFocusGenre(this.QRSelectSongUniqueId) == false) then
				return
			else
				this.is_QRcodeSequence        = true
				this.songPanelIndexOffsetType = this.kScrollOffsetTypeWait
				
				this:SetSongDataAll()
				this:ClosePanelOutside()
			end
			
		end,

-- ↓↓曲選択時のスキップ(早送り)機能
		kSkipping_input_hit_count = 2,	-- スキップと判定するまでの叩き数
		kSkipping_input_frame_count = 7,	-- スキップと判定するまでのフレーム数
		kSkipping_ignore_frame_count = 60, -- スキップ中の入力無視フレーム数

		-- 叩いた数 (左は-, 右は+方向にカウントする)
		skipping_input_hit_counter_1p = 0,
		skipping_input_hit_counter_2p = 0,
		-- 前の入力からのフレーム数
		skipping_input_frame_counter_1p = 0,
		skipping_input_frame_counter_2p = 0,
		-- 発動からのフレーム数
		skipping_ignore_frame_counter = 0,
		-- スキップ方向 -1は左 0はなし 1は右
		skipping_direction = 0,

		-- 変数リセット
		ResetSkippingVariables = function(this)
			--Debug.PrintString("ResetSkippingVariables")
			this.skipping_input_hit_counter_1p = 0
			this.skipping_input_hit_counter_2p = 0
			this.skipping_input_frame_counter_1p = 0
			this.skipping_input_frame_counter_2p = 0
			this.skipping_ignore_frame_counter = 0
		end,

		-- 更新関数	
		ProcessSkipping = function(this)
			-- Debug.PrintString("ProcessSkipping")
			-- 無視期間が終了したらリセット ただし すでに条件を満たしていたらなし
			if(this.skipping_ignore_frame_counter >0) then
				this.skipping_ignore_frame_counter = this.skipping_ignore_frame_counter -1
				if(this.skipping_ignore_frame_counter == 0) then
					Debug.PrintString("zero")
					if( this.skipping_input_hit_counter_1p >= this.kSkipping_input_hit_count
						or this.skipping_input_hit_counter_1p <= -this.kSkipping_input_hit_count
						or this.skipping_input_hit_counter_2p >= this.kSkipping_input_hit_count
						or this.skipping_input_hit_counter_2p <= -this.kSkipping_input_hit_count
					) then
						Debug.PrintString("continuing")
					else
						this:ResetSkippingVariables()
						this.skipping_direction = 0
					end
				end
			end

			-- 1p側処理
			if(is_joinPlayer[1]) then
				-- 一定期間入力がなければリセット ただし無視期間中に条件を満たしたときは無効
				if( this.skipping_ignore_frame_counter == 0
					and  not(
						this.skipping_input_hit_counter_1p <= -this.kSkipping_input_hit_count
						or this.skipping_input_hit_counter_1p >= this.kSkipping_input_hit_count
					)
				 ) then
					if(this.skipping_input_frame_counter_1p > 0) then
						this.skipping_input_frame_counter_1p = this.skipping_input_frame_counter_1p - 1
						if(this.skipping_input_frame_counter_1p == 0) then
							this.skipping_input_hit_counter_1p = 0
						end
					end
				end
				-- 右側カツ入力があった
				if(Input.GetTrigger(Input.PLAYER1_RIGHT)) then
					Debug.PrintString("Input.PLAYER1_RIGHT")
					if(this.skipping_input_hit_counter_1p < 0) then
						this.skipping_input_hit_counter_1p = 0
					end
					-- 無視期間中は進行方向に1回入ったら即max
					if(this.skipping_ignore_frame_counter == 0) then
						this.skipping_input_hit_counter_1p = this.skipping_input_hit_counter_1p +1
					else
						if(this.skipping_direction >= 1) then
							this.skipping_input_hit_counter_1p = this.kSkipping_input_hit_count
						else
							this:ResetSkippingVariables()
							this.skipping_direction = 0
						end
					end
					this.skipping_input_frame_counter_1p = this.kSkipping_input_frame_count
					Debug.PrintString(this.skipping_input_hit_counter_1p)
				end
				-- 左側カツ入力があった
				if(Input.GetTrigger(Input.PLAYER1_LEFT)) then
					Debug.PrintString("Input.PLAYER1_LEFT")
					if(this.skipping_input_hit_counter_1p > 0) then
						this.skipping_input_hit_counter_1p = 0
					end
					-- 無視期間中は進行方向に1回入ったら即max
					if(this.skipping_ignore_frame_counter == 0) then
						this.skipping_input_hit_counter_1p = this.skipping_input_hit_counter_1p -1
					else
						if(this.skipping_direction <= -1) then
							this.skipping_input_hit_counter_1p = -this.kSkipping_input_hit_count
						else
							this:ResetSkippingVariables()
							this.skipping_direction = 0
						end
					end
					this.skipping_input_frame_counter_1p = this.kSkipping_input_frame_count
					Debug.PrintString(this.skipping_input_hit_counter_1p)
				end
			end

			-- 2p側処理
			if(is_joinPlayer[2]) then
				-- 一定期間入力がなければリセット ただし無視期間中に条件を満たしたときは無効
				if( this.skipping_ignore_frame_counter == 0
					and  not(
						this.skipping_input_hit_counter_2p <= -this.kSkipping_input_hit_count
						or this.skipping_input_hit_counter_2p >= this.kSkipping_input_hit_count
					)
				 ) then
					if(this.skipping_input_frame_counter_2p > 0) then
						this.skipping_input_frame_counter_2p = this.skipping_input_frame_counter_2p - 1
						if(this.skipping_input_frame_counter_2p == 0) then
							this.skipping_input_hit_counter_2p = 0
						end
					end
				end
				-- 右側カツ入力があった
				if(Input.GetTrigger(Input.PLAYER2_RIGHT)) then
					Debug.PrintString("Input.PLAYER2_RIGHT")
					if(this.skipping_input_hit_counter_2p < 0) then
						this.skipping_input_hit_counter_2p = 0
					end
					-- 無視期間中は進行方向に1回入ったら即max
					if(this.skipping_ignore_frame_counter == 0) then
						this.skipping_input_hit_counter_2p = this.skipping_input_hit_counter_2p +1
					else
						if(this.skipping_direction >= 1) then
							this.skipping_input_hit_counter_2p = this.kSkipping_input_hit_count
						else
							this:ResetSkippingVariables()
							this.skipping_direction = 0
						end
					end
					this.skipping_input_frame_counter_2p = this.kSkipping_input_frame_count
					Debug.PrintString(this.skipping_input_hit_counter_2p)
				end
				-- 左側カツ入力があった
				if(Input.GetTrigger(Input.PLAYER2_LEFT)) then
					Debug.PrintString("Input.PLAYER2_LEFT")
					if(this.skipping_input_hit_counter_2p > 0) then
						this.skipping_input_hit_counter_2p = 0
					end
					-- 無視期間中は進行方向に1回入ったら即max
					if(this.skipping_ignore_frame_counter == 0) then
						this.skipping_input_hit_counter_2p = this.skipping_input_hit_counter_2p -1
					else
						if(this.skipping_direction <= -1) then
							this.skipping_input_hit_counter_2p = -this.kSkipping_input_hit_count
						else
							this:ResetSkippingVariables()
							this.skipping_direction = 0
						end
					end
					this.skipping_input_frame_counter_2p = this.kSkipping_input_frame_count
					Debug.PrintString(this.skipping_input_hit_counter_2p)
				end
			end

		end,

		-- 通常移動を無視するか
		IsIgnoreKatsu = function(this)
			if(this:IsSkippingIgnoreTime()) then return true end
			return false
		end,

		-- 判定状況結果を返す関数
		IsSkippingIgnoreTime = function(this)
			-- Debug.PrintString("IsSkippingIgnoreTime")
			if(this.skipping_ignore_frame_counter == 0) then return false
			else return true
			end
		end,

		IsSkippingTriggeredLeft = function(this)
			-- Debug.PrintString("IsSkippingTriggeredLeft")
			if(this:IsSkippingIgnoreTime()) then return false end
			local returnValue = false
			if(this.skipping_input_hit_counter_1p <= -this.kSkipping_input_hit_count) then returnValue = true end
			if(this.skipping_input_hit_counter_2p <= -this.kSkipping_input_hit_count) then returnValue = true end
			if(returnValue) then
				this:ResetSkippingVariables()
				this.skipping_direction = -1
				this.skipping_ignore_frame_counter = this.kSkipping_ignore_frame_count
			end
			return returnValue
		end,

		IsSkippingTriggeredRight = function(this)
			-- Debug.PrintString("IsSkippingTriggeredRight")
			if(this:IsSkippingIgnoreTime()) then return false end
			local returnValue = false
			if(this.skipping_input_hit_counter_1p >= this.kSkipping_input_hit_count) then returnValue = true end
			if(this.skipping_input_hit_counter_2p >= this.kSkipping_input_hit_count) then returnValue = true end
			if(returnValue) then
				this:ResetSkippingVariables()
				this.skipping_direction = 1
				this.skipping_ignore_frame_counter = this.kSkipping_ignore_frame_count
			end
			return returnValue
		end,
-- ↑↑曲選択時のスキップ(早送り)機能


		-- SongSelectQRで使っているので関数だけ作っておくシリーズ
		Set2PEntryEnableFlag = function(this, setFlag)
		end
	}
end
