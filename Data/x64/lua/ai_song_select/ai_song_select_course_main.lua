-- AI難易度選択画面.難易度シーケンスLua
-- Masayuki_Teraoka@al.bandainamco.jp

AISongSelectCourseMain = {}
-- 使うクラスを読み込む
require("common.Sound")
require("ai_song_select.ai_song_select_course_board")
require("ai_song_select.ai_song_select_option_main")

-- このクラス
function AISongSelectCourseMain.New(timer_set)
	return
	{
		-- ロード
		LoadMovieCourseMain = function(this)
			Lumen.LoadMovie("lumen/000_default/enso_ai/song_select/ai_song_select_main_diff", "course_select")
			if(this.is_optionSetUp == false)then
				songselectoption_ = AISongSelectOptionMain.New(1)
				songselectoption_:LoadMovieOptionMain()
				this.is_optionSetUp = true
			end
		end,
		
		--　ステートクラスの作成
		State_ = State.New("AISongSelectCourseMain"),
		
		--　一人プレイ時のカーソルのラベル名
		tbl_SoloCursorMoveLabel  = {"pos_center_1","pos_center_2","pos_center_3","pos_center_4","pos_center_5","pos_center_6"},
		
		--　選択できる板のラベル名
		tbl_CourseNameLabel      = {"back","option","easy","normal","hard","oni"},
		
		mc_CourseBoard_         = {},							--　各難易度の板クラス
		mc_BackBoard_           = 0,							--　戻る看板のムービークリップ
		mc_OptionBoard_         = 0,							--　オプション看板のムービークリップ
		
		wait_end_cnt            = 1.5 * Common.FPS * timer_set, -- 難易度を決定後にこのカウント後シーケンスが終了する
		
		start_request_bestsection_cnt  = 0,						--　ベストスコアをリクエストしてからのカウント
		wait_request_bestsection_cnt   = 2.0 * Common.FPS,		--　この数字のタイミングでベストスコアのリクエストを行う

		INPUT_1P_LEFT			= 1,							-- プレイヤー/左カツ
		INPUT_1P_RIGHT			= 2,							-- プレイヤー/右カツ
		INPUT_1P_DECIDE			= 3,							-- プレイヤー/ドン
		INPUT_2P_LEFT			= 4,							-- プレイヤー/左カツ
		INPUT_2P_RIGHT			= 5,							-- プレイヤー/右カツ
		INPUT_2P_DECIDE			= 6,							-- プレイヤー/ドン
		
		kPlayer1				= 1,							-- 1P側定数
		kPlayer2				= 2,							-- 2P側定数
		
		kopen_oni_count         = 10,							--　このカウントだけふちを叩くと、おにを開放する
		kopen_ura_count         = 10,							--　このカウントだけふちを叩くと、うらを開放する
		
		-- カードユーザーの場合
		------------------------------------
		kCourseBackCard 			    = 1,					-- 戻る看板インデックス
		kCourseOptionCard 			    = 2,					-- オプション看板インデックス
		kCourseEasyCard 			    = 3,					-- かんたん看板インデックス
		kCourseNormalCard 			    = 4,					-- ふつう看板インデックス
		kCourseHardCard 			    = 5,					-- むずかしい看板インデックス
		kCourseOniCard 				    = 6,					-- おに看板インデックス
		kCourseUraCard 				    = 7,					-- おに裏看板インデックス
		------------------------------------
		
		-- コインユーザーの場合
		------------------------------------
		kCourseBack 			        = 1,					-- 戻る看板インデックス
		kCourseEasy 			        = 2,					-- かんたん看板インデックス
		kCourseNormal 			        = 3,					-- ふつう看板インデックス
		kCourseHard 			        = 4,					-- むずかしい看板インデックス
		kCourseOni 				        = 5,					-- おに看板インデックス
		kCourseUra 				        = 6,					-- おに裏看板インデックス
		------------------------------------			
		
		-- タイムアップ時の場合(コイン)			
		------------------------------------			
		kCourseEasyTime 			    = 1,					-- かんたん看板インデックス		
		kCourseNormalTime 			    = 2,					-- ふつう看板インデックス
		kCourseHardTime 			    = 3,					-- むずかしい看板インデックス
		kCourseOniTime 				    = 4,					-- おに看板インデックス
		kCourseUraTime 				    = 5,					-- おに裏看板インデックス
		------------------------------------			
		
		-- タイムアップ時の場合(カード)			
		------------------------------------			
		kCourseOptionCardTime 			= 1,					-- オプション看板インデックス				
		kCourseEasyCardTime 			= 2,					-- かんたん看板インデックス		
		kCourseNormalCardTime 			= 3,					-- ふつう看板インデックス
		kCourseHardCardTime 			= 4,					-- むずかしい看板インデックス
		kCourseOniCardTime 				= 5,					-- おに看板インデックス
		kCourseUraCardTime 				= 6,					-- おに裏看板インデックス
		------------------------------------			
		
		-- 演奏オプションタイムアップ時の場合(カード)			
		------------------------------------			
		kCourseEasyOptionTime 			= 1,					-- かんたん看板インデックス
		kCourseNormalOptionTime 		= 2,					-- ふつう看板インデックス
		kCourseHardOptionTime 			= 3,					-- むずかしい看板インデックス
		kCourseOniOptionTime 			= 4,					-- おに看板インデックス
		kCourseUraOptionTime 			= 5,					-- おに裏看板インデックス
		------------------------------------

		-- C++側に対応する難易度Index
		------------------------------------
		kCourseEasyCPP 			        = 0,					-- かんたんインデックス
		kCourseNormalCPP 		        = 1,					-- ふつうインデックス
		kCourseHardCPP 			        = 2,					-- むずかしいインデックス
		kCourseOniCPP 			        = 3,					-- おにインデックス
		kCourseUraCPP 			        = 4,					-- おに裏インデックス
		------------------------------------			
					
		kScrollOffsetTypeWait	        = 1,					-- 待機
		kScrollOffsetTypeMoveR	        = 2,					-- 右へ移動＝右の難易度を選択。
		kScrollOffsetTypeMoveL	        = 3,					-- 左へ移動＝左の難易度を選択。
					
		kResultWaiting			        = 1,					-- 開始待機
		kResultRunning			        = 2,					-- 実行中
		kResultCanseled			        = 3,					-- キャンセルされた（モード選択に戻る）
		kResultDecided			        = 4,					-- 決定された（曲ロード画面へ進む）
					
		kSelectNumber			        = 1,					-- 選択中の看板.
		scrollDirection 		        = 0,					-- スクロール方向
					
		coursePanelIndexOffsetType      = 1, 					-- 使用するオフセットテーブルの種類

		resultType                      = kResultWaiting,		-- 決定した結果
		
		currentCourseIndex              = 1,				-- 現在選択中のインデックス
		selectIndex                     = 1,				--　決定したインデックス
		
		mc_board                        = 0,					--　main/board のMCを入れる

		is_inputEnable_1p               = false,				-- 1P側入力受付可能フラグ
		is_inputEnable_2p               = false,				-- 2P側入力受付可能フラグ
		is_eraseBackPanel               = false,				-- 戻る看板を消したか
		is_timeUp                       = false,				-- タイムアップフラグ
		is_timeUpOption                 = false,				-- オプションを開いている状態でタイムアップ
		is_selectEnd                    = false,				-- 全選択が終わったか
		is_optionSetUp                  = false,				-- オプションのセットアップが終わったか
		is_boardIn                      = false,				--　難易度の板が表示完了したか
		is_cursorIn                     = false,				--　カーソルが表示完了したか
		is_frameIn                      = false,				--　ボードがフレームインしたか
		is_timerStop                    = false,				--　タイマーを止めるか
		is_allSetUp	                    = false,				--　全てのセットアップが完了したか
		
		cursorLimitFlag                 = false,				-- カーソルが限界まで進んでいるか（1P,2P）
		openOniFlag                     = false,				-- 難易度おにを開放済みか
		turnOniFlag                     = false,				--　おにぱねるを回転済みか（trueならうらが見えている）
		
		open_oni_count                  = 0,					--　難易度おにを開放する際のカウント値
		open_ura_count                  = 0,					--　難易度おに裏を開放する際のカウント値
		
		Init = function(this)

			-- ステートマシンを組み立てておく、実際に実行されるのはステート処理を実行するとき
			this.State_.func_["Begin"] = function()
				-- 各種パーツ読み込み
				if(this.is_optionSetUp == false)then
					Debug.PrintString("オプションの設定")
					songselectoption_ = AISongSelectOptionMain.New(1)
					songselectoption_:LoadMovieOptionMain()
					songselectoption_:Init()
					this.is_optionSetUp = true
				end

				this.State_:SetState("Loading")
			end
			
			--　各種値の初期化
			this.State_.func_["Loading"] = function()
				if (Lumen.IsLoadMovieFinish() == true) then
					-- ムービークリップ取得
					this.mc_main = Lumen.GetMovieClip("main",true)
					this.mc_board        = Lumen.GetMovieClip("main/course_select",true)
					
					this.mc_BackBoard_   = this.mc_board:GetChildMc("main/board/back")
					this.mc_OptionBoard_ = this.mc_board:GetChildMc("main/board/option")
					
					for idx = 1, 4 do						
						this.mc_CourseBoard_[idx] = {}
						this.mc_CourseBoard_[idx] = AISongSelectCourseBoard.New(this.mc_board:GetChildMc("main/board/board_"..idx))
						this.mc_CourseBoard_[idx]:GetCourseRecordInfo()
						this.mc_CourseBoard_[idx]:AllBoardInitialize(idx)
					end
					
					-- カードプレイヤーがいない場合のイニシャライズ
					if (is_CardPlayer == false) then 
						this:EraseOptionBoard()
					end
					
					-- おにユーザーがいないのであれば、おにパネルは消す
					if (playerOpenLevel <= kPlayerOpenNormal) then
						this:EraseBoardOni()
					else 
						this.openOniFlag = true --　そうじゃないならおにフラグは建てておく
						this.mc_board.board.board_4:SetVisible(true)
						this.mc_board.board.board_4:GotoAndStop("course_oni")
					end
					
					TSound:Play("voice_senkuoku_v12a","select_song")

					this.is_inputEnable_1p = true
					this.is_inputEnable_2p = true

					this.cursorLimitFlag = false

					this:SetSongText()
					this:InitializePlayerCursor()
					this:InitializeMainBoardBackGround()

					this.currentCourseIndex = 1
					this.selectIndex = 1

					-- タイムアップで入ってきた場合戻るパネルを消去
					if (this.is_timeUp == true) then
						this:EraseBoardBack() 
					end

					this:ResetDispCursorFrame()
					--this:ResetDispCursorFrame(2)
					
					this:StartFocusCourseMark()
					this:UpdateCourseChoise(this.selectIndex)
					
					this:SetDefaultCourse()

					-- 操作ガイド
					this.mc_board.main.board.guide_s_taiko:GotoAndStop("init")
					this.mc_board.main.board.guide_s_taiko.select_instance:SetText("text_guide_instance","text_guide","select")
					this.mc_board.main.board.guide_s_taiko.decide_instance:SetText("text_guide_instance","text_guide","decide")

					-- 選択フレーム
					this.mc_board.main.board.panel_frame_1.frame:GotoAndStop("in")
					this.mc_board.main.board.course_frame_1.frame:GotoAndStop("in")

					this.is_boardIn = true
					this.is_allSetUp = true
					
					this.State_:SetState("StartWait")
				end
			end
			
			-- 再度シーケンスが戻った時用
			this.State_.func_["ReLoading"] = function()
				Debug.PrintString("リロード")

				if (Lumen.IsLoadMovieFinish() == true) then
					
					for idx = 1, 4 do
						this.mc_CourseBoard_[idx]:GetCourseRecordInfo()
						this.mc_CourseBoard_[idx]:AllBoardInitialize(idx)
					end
					
					this.is_inputEnable_1p = true
					this.is_inputEnable_2p = true
					
					this.cursorLimitFlag = false

					this:SetSongText()
					this:InitializePlayerCursor()
					this:InitializeMainBoardBackGround()
					
					this.currentCourseIndex = 1
					this.selectIndex = 1
					
					this:ResetOniUraCount()

					this.coursePanelIndexOffsetType = 1
					this.scrollDirection = 0
					
					-- タイムアップで入ってきた場合戻るパネルを消去
					if (this.is_timeUp == true) then
						this:EraseBoardBack() 
					end

					this:ResetDispCursorFrame()
					
					-- 演奏オプション
					songselectoption_:ReStartOption()
					
					TSound:Play("voice_senkuoku_v12a","select_song")

					this:StartFocusCourseMark()
					this:UpdateCourseChoise(this.selectIndex)
					
					this:SetDefaultCourse()
					
					this.mc_board.main.board.guide_s_taiko:GotoAndStop("init")
					
					this.mc_board.main.board.panel_frame_1.frame:GotoAndStop("in")
					this.mc_board.main.board.course_frame_1.frame:GotoAndStop("in")

					this.is_boardIn = true
					this.is_allSetUp = true
					
					this.State_:SetState("StartWait")
				end
			end
			
			--　メインシーケンスに入る前のウェイト
			this.State_.func_["StartWait"] = function()

				if(this.is_boardIn)then
					this:waitBoardIn()
				elseif(this.is_cursorIn or this.is_frameIn)then
					this:waitCursorIn()
					this.mc_board.main.board.guide_s_taiko:GotoAndPlay("fade_in")
				end

				if(this.is_boardIn == false and this.is_cursorIn == false)then
					this.is_inputEnable_1p = true
					this.is_inputEnable_2p = true
					this.State_:SetState("Main")
				end
			end
			
			--　メインシーケンス
			this.State_.func_["Main"] = function()
			
				this.resultType = this.kResultRunning

				this:keyInput_1P()
				this:keyInput_2P()
				
			end
			
			--　一人プレイで曲を選んでのEndシーケンス
			this.State_.func_["SoloEnd"] = function()
				
				if (this.is_selectEnd == false) then
					TSound:Play("voice_senkuoku_v12a","select_difficulty_ai_c")

					this.mc_board.main.board.course_frame_1.frame:GotoAndPlay("choose")
					this.mc_board.main.board.mark_1:GotoAndPlay("course_decide_start")
					
					Don.SetNonLoopAnimation(0,"entry_select_loop_p2",true)
					Don.SetNonLoopAnimation(1,"entry_select_loop_p2",true)
					
					this.is_selectEnd = true
				end
				
				if (this.mc_board.main.board.mark_1:IsPlay() == false) then 
					this.State_:SetState("WaitEnd")
				end
				
				Debug.PrintString(course)
				Debug.PrintString(selectedCourse1P)
				Debug.PrintString("CourseSelectSoloEnd")
			end
			
			--　戻るを選んでのEndシーケンス
			this.State_.func_["CancelEnd"] = function()

				this.resultType = this.kResultCanseled
				
				this.is_selectEnd = false
				this.is_allSetUp = false
				
				if (this.turnOniFlag == true) then this.mc_CourseBoard_[4]:ChangeOniBoard() end
				this.turnOniFlag = false

				Don.SetLoopAnimation(0,"result_clear_loop",true)

				Debug.PrintString("CourseSelectSoloCancelEnd")
			end
			
			--　最後のEndシーケンス
			this.State_.func_["WaitEnd"] = function()
				
				this.is_timerStop = true
				this:waitEndCnt()
				
				if(this.wait_end_cnt <= 0) then
					this.resultType = this.kResultDecided
				end
			end
			
			--　難易度おにを開放時のシーケンス
			this.State_.func_["OpenOniPanel"] = function()
				
				--　おに開放時のアニメーションが終わったらメインへ遷移
				if(this.mc_board.board.board_4:IsPlay() == false) then
					this:OniPanelChangeEnd()
					this.State_:SetState("Main")
				end
			end

			--　おにパネルを難易度おに裏に回転時のシーケンス
			this.State_.func_["ChangeUraPanel"] = function()

				if(this.mc_CourseBoard_[4].mc_name_:IsPlay() == false) then
					this:OniPanelChangeEnd()
					this.State_:SetState("Main")
				end
			end

			--　おに裏パネルを難易度おにに回転時のシーケンス
			this.State_.func_["ChangeOniPanel"] = function()

				if(this.mc_CourseBoard_[4].mc_name_:IsPlay() == false) then
					this:OniPanelChangeEnd()
					this.State_:SetState("Main")
				end
			end

		end,
		
	-- ここまでInit
		
		--　ここのカウントが0になったら、終わった通知を返す
		waitEndCnt = function(this)
			this.wait_end_cnt = this.wait_end_cnt -1
		end,

		-- ボードがフェードインするまで待機
		waitBoardIn = function(this)
			if(this.mc_main:IsPlay() )then
				-- フェードイン中
			else
				-- フェードイン完了後の処理
				this.is_cursorIn = true
				this.is_frameIn = true
				this.is_boardIn = false

				this.mc_board.main.board.player_cursor_1.cursor:GotoAndPlay("in")
				this:StartCursorFrame()
			end
		end,

		-- カーソルがフェードインするまで待機
		waitCursorIn = function(this)
			if(this.mc_board.main.board.player_cursor_1.cursor:IsPlay() == false)then
				this.is_cursorIn = false

				this.mc_board.main.board.panel_frame_1.frame:GotoAndPlay("select")
				this.mc_board.main.board.course_frame_1.frame:GotoAndPlay("select")
			end
		end,
		
		--　ステートの更新
		Update = function(this)
			-- ステート処理
			this.State_:Update()
			songselectoption_.State_:Update()
			
			if (this.is_allSetUp == true) then
				for idx = 1, 4 do
					this.mc_CourseBoard_[idx]:UpdateCompeIcon()
				end
			end
		end,
	-- ここまでUpdate
		
		--　再度シーケンスが戻った時用
		ReStartCourseSelect = function(this)
			this.State_:SetState("ReLoading")
		end,

		-- 左右入力
		MoveCursor = function(this, direction)
			if(this.State_.state_ == "CancelEnd")then
				return
			end
			
			this.scrollDirection = direction;
			
			--　左方向にカツ入力を入れたら、カウントを0に戻す
			if (this.scrollDirection < 0) then 
				this:ResetOniUraCount()
			end
			
			this.cursorLimitFlag = false
			
			this.selectIndex = (this.currentCourseIndex + this.scrollDirection)
			
			if (this.selectIndex > #this.tbl_CourseNameLabel) then
				this.selectIndex = #this.tbl_CourseNameLabel
				
				this.cursorLimitFlag = true
				
				this.open_oni_count = this.open_oni_count + 1
				
				if(this.openOniFlag == true) then
					this.open_ura_count = this.open_ura_count + 1
				end
				
				if (this.open_oni_count >= this.kopen_oni_count and this.openOniFlag == false) then
					this:OpenOniPanel()
					
				elseif(this.open_ura_count >= this.kopen_ura_count and this.openOniFlag == true) then
					if (selectedSongData.course_star[5] >= 1) then this:TurnOniPanel() end
				end
				
			elseif (this.selectIndex < 1) then
				this.cursorLimitFlag = true
				this.selectIndex = 1
			end
			
			Debug.PrintString(this.selectIndex)
			
			this:UpdateCourseChoise(this.selectIndex)
			
			this:PlayerMoveSelect(direction)

		end,
		
		-- 1Pキー入力
		keyInput_1P = function (this)
			-- オプション中なら抜ける
			if(songselectoption_:GetOpenOptionFlag()) then
				return
			end
			
			if (this:CheckInput() == this.INPUT_1P_DECIDE) then

				-- ドンのSE
				TSound:Play("se_common_v12a","don_l")
				
				this:CourseSet()
				this.is_inputEnable_1p = false
				
				if (this.is_timeUp == false) then
					if (courseId > this.kCourseBack) then 
						this.State_:SetState("SoloEnd")
					
					elseif (this.is_timeUpOption == true) then
						this.State_:SetState("SoloEnd")
					elseif (courseId <= this.kCourseBack and this.is_timeUp == false and this.is_timeUpOption == false) then
						this.State_:SetState("CancelEnd")
					end
					
				else
					if (courseId >= this.kCourseEasyTime) then
						this.State_:SetState("SoloEnd")					
					end
				end
				
				if(this.is_timeUpOption == false)then
					if (is_CardPlayer == true) then
						
						if(this.is_timeUp == false) then
						
							if (courseId == this.kCourseOptionCard) then
								this.State_:SetState("Main")
								this.is_inputEnable_1p = true
								songselectoption_:Tween_SlideIn()
								
								TSound:Play("voice_senkuoku_v12a","select_option_l")
							end
						
						else
							if (courseId == this.kCourseOptionCardTime) then
								this.State_:SetState("Main")
								this.is_inputEnable_1p = true
								songselectoption_:Tween_SlideIn()
								
								TSound:Play("voice_senkuoku_v12a","select_option_l")
							end
						end
					end
				end
				
			elseif (this:CheckInput() == this.INPUT_1P_RIGHT) then
				-- 右ふち
				-- カツのSE
				TSound:Play("se_common_v12a","katsu_l")
				this:MoveCursor(1)
				
			elseif (this:CheckInput() == this.INPUT_1P_LEFT) then
				-- 左ふち
				-- カツのSE				
				TSound:Play("se_common_v12a","katsu_l")
				this:MoveCursor(-1)
				
			end

		end,
		
		-- 2Pキー入力
		keyInput_2P = function (this)
		-- オプション中なら抜ける
			if(songselectoption_:GetOpenOptionFlag()) then
				return
			end

			if (this:CheckInput() == this.INPUT_2P_DECIDE) then
				
				-- ドンのSE
				TSound:Play("se_common_v12a","don_r")

				this:CourseSet()
				this.is_inputEnable_2p = false

				if (this.is_timeUp == false) then
					if (courseId > this.kCourseBack) then 
						this.State_:SetState("SoloEnd")
					elseif (this.is_timeUpOption == true) then
						this.State_:SetState("SoloEnd")
					elseif (courseId <= this.kCourseBack and this.is_timeUp == false and this.is_timeUpOption == false) then
						this.State_:SetState("CancelEnd")
					end
				else
					if (courseId >= this.kCourseEasyTime) then 
						this.State_:SetState("SoloEnd")		
					end
				end
				
				if(this.is_timeUpOption == false)then
					if (is_CardPlayer == true) then
						if(this.is_timeUp == false) then
							if (courseId == this.kCourseOptionCard) then
								this.State_:SetState("Main")					
								this.is_inputEnable_2p = true
								songselectoption_:Tween_SlideIn()
								
								TSound:Play("voice_senkuoku_v12a","select_option_r")
							end
						
						else
							if (courseId == this.kCourseOptionCardTime) then
								this.State_:SetState("Main")
								this.is_inputEnable_2p = true
								songselectoption_:Tween_SlideIn()
								
								TSound:Play("voice_senkuoku_v12a","select_option_r")
							end
						end
					end
				end

			elseif (this:CheckInput() == this.INPUT_2P_RIGHT) then
				-- 右ふち				
				-- カツのSE
				TSound:Play("se_common_v12a","katsu_r")
				this:MoveCursor(1)
				
			elseif (this:CheckInput() == this.INPUT_2P_LEFT) then
				-- 左ふち
				-- カツのSE
				TSound:Play("se_common_v12a","katsu_r")
				this:MoveCursor(-1)
			end
		end,
		
		--　決定した難易度をセットする
		CourseSet = function(this)
		
			-- カードプレイヤーがいない場合
			if (is_CardPlayer == false) then 
				-- タイムアップしていない
				if (this.is_timeUp == false) then
					if (this.selectIndex == this.kCourseEasy) then
						course = this.kCourseEasyCPP
					elseif (this.selectIndex == this.kCourseNormal) then
						course = this.kCourseNormalCPP
					elseif (this.selectIndex == this.kCourseHard) then
						course = this.kCourseHardCPP
					elseif (this.selectIndex == this.kCourseOni and this.turnOniFlag == true) then
						course = this.kCourseUraCPP
					elseif (this.selectIndex == this.kCourseOni) then
						course = this.kCourseOniCPP
					end
				else
				-- タイムアップしている
					if (this.selectIndex == this.kCourseEasyTime) then
						course = this.kCourseEasyCPP
					elseif (this.selectIndex == this.kCourseNormalTime) then
						course = this.kCourseNormalCPP
					elseif (this.selectIndex == this.kCourseHardTime) then
						course = this.kCourseHardCPP
					elseif (this.selectIndex == this.kCourseOniTime and this.turnOniFlag == true) then
						course = this.kCourseUraCPP
					elseif (this.selectIndex == this.kCourseOniTime) then
						course = this.kCourseOniCPP
					end
				end
			else
			-- カードプレイヤーがいる
				-- タイムアップしている
				if(this.is_timeUpOption == true)then
					-- 処理
					if (this.selectIndex == this.kCourseEasyOptionTime ) then
						course = this.kCourseEasyCPP
					elseif (this.selectIndex == this.kCourseNormalOptionTime) then
						course = this.kCourseNormalCPP
					elseif (this.selectIndex == this.kCourseHardOptionTime) then
						course = this.kCourseHardCPP
					elseif (this.selectIndex == this.kCourseOniOptionTime and this.turnOniFlag == true) then
						course = this.kCourseUraCPP
					elseif (this.selectIndex == this.kCourseOniOptionTime) then
						course = this.kCourseOniCPP
					end
				else
				-- タイムアップしていない
					if (this.is_timeUp == false) then

						if (this.selectIndex == this.kCourseEasyCard) then
							course = this.kCourseEasyCPP
						elseif (this.selectIndex == this.kCourseNormalCard) then
							course = this.kCourseNormalCPP
						elseif (this.selectIndex == this.kCourseHardCard) then
							course = this.kCourseHardCPP
						elseif (this.selectIndex == this.kCourseOniCard and this.turnOniFlag == true) then
							course = this.kCourseUraCPP
						elseif (this.selectIndex == this.kCourseOniCard) then
							course = this.kCourseOniCPP
						end
					else
						if (this.selectIndex == this.kCourseEasyCardTime) then
							course = this.kCourseEasyCPP
						elseif (this.selectIndex == this.kCourseNormalCardTime) then
							course = this.kCourseNormalCPP
						elseif (this.selectIndex == this.kCourseHardCardTime) then
							course = this.kCourseHardCPP
						elseif (this.selectIndex == this.kCourseOniCardTime and this.turnOniFlag == true) then
							course = this.kCourseUraCPP
						elseif (this.selectIndex == this.kCourseOniCardTime) then
							course = this.kCourseOniCPP
						end
					end
				end
			end
			
			selectedCourse1P = course
			
		end,
		
		--　カーソルを動かした時の表示物切替え
		PlayerMoveSelect = function(this,  direction)
			
			-- カーソルが限界まで到達してないならカーソルのアニメーションを動かす
			if (this.cursorLimitFlag == false) then 
				this.mc_board.main.board.player_cursor_1.cursor:GotoAndPlay("move")
			end

			-- 移動方向によって難易度板のindexの対応テーブルを切り替え、アニメさせる(1P)
			if (direction < 0) then
				this.coursePanelIndexOffsetType = this.kScrollOffsetTypeMoveR
				this.mc_board.main.board.player_cursor_1:GotoAndStop(this.tbl_SoloCursorMoveLabel[this.currentCourseIndex])
			else
				this.coursePanelIndexOffsetType = this.kScrollOffsetTypeMoveL
				this.mc_board.main.board.player_cursor_1:GotoAndStop(this.tbl_SoloCursorMoveLabel[this.currentCourseIndex])
			end
		end,
		
		-- 楽曲板内のテキスト指定
		SetSongText = function(this)
		
			-- 楽曲名
			this.mc_board:SetText("main/board/text_title_song","text_title_song","song_"..selectedSongData.song_id)
			-- サブ表記
			this.mc_board:SetText("main/board/text_song_title_sub","text_song_title_sub","song_sub_"..selectedSongData.song_id)
			-- ルビ
			this.mc_board:SetText("main/board/text_song_title_ruby","text_song_title_ruby","song_detail_"..selectedSongData.song_id)
			
		end,
		
		-- メインボードの背景の色を選んだ楽曲のジャンルに合わせて変更する
		InitializeMainBoardBackGround = function(this)
		
			-- ショップなら専用IDを使う
			if (genreIdStr == "shop") then
				this.mc_board.main.board.background:GotoAndStop(shopIdStr)
			else
				this.mc_board.main.board.background:GotoAndStop(genreIdStr)
			end
		end,
		
		-- コインユーザー向けボード表示制御(オプションを消す)
		EraseOptionBoard = function(this)
		
			this.mc_board.board.option:SetVisible(false)
			
			for i = 1, #this.tbl_SoloCursorMoveLabel do
				if (this.tbl_SoloCursorMoveLabel[i] == "pos_center_2") then
					table.remove(this.tbl_SoloCursorMoveLabel, i)
				end
			end
			
			for i = 1, #this.tbl_CourseNameLabel do
				if (this.tbl_CourseNameLabel[i] == "option") then
					table.remove(this.tbl_CourseNameLabel, i)
				end
			end

		end,
		
		-- おにボード表示制御(おにを消す)
		EraseBoardOni = function(this)
			
			this.mc_board.board.board_4:SetVisible(false)
			
			for i = 1, #this.tbl_SoloCursorMoveLabel do
				if (this.tbl_SoloCursorMoveLabel[i] == "pos_center_6") then
					table.remove(this.tbl_SoloCursorMoveLabel, i)
				end
			end
			
			for i = 1, #this.tbl_CourseNameLabel do
				if (this.tbl_CourseNameLabel[i] == "oni") then
					table.remove(this.tbl_CourseNameLabel, i)
				end
			end
		end,
		
		-- 戻るボード表示制御(もどるを消す)
		EraseBoardBack = function(this)
			
			this.is_eraseBackPanel = true
			
			if(is_CardPlayer == true) then
				this.currentCourseIndex = 2
				this.selectIndex        = 2
			end
			
			this.mc_board.board.back:GotoAndStop("off")
			
			for i = 1, #this.tbl_SoloCursorMoveLabel do
				if (this.tbl_SoloCursorMoveLabel[i] == "pos_center_1") then
					table.remove(this.tbl_SoloCursorMoveLabel, i)
				end
			end
			
			for i = 1, #this.tbl_CourseNameLabel do
				if (this.tbl_CourseNameLabel[i] == "back") then
					table.remove(this.tbl_CourseNameLabel, i)
				end
			end
		end,

		-- 演奏オプションボード表示制御(演奏オプションを消す)
		EraseBoardOption = function(this)
			local count = 0

			this.is_eraseBackPanel = true
			
			-- 戻るボードとオプションボードを設定オフ
			this.mc_board.board.back:GotoAndStop("off")
			this.mc_board.board.option:GotoAndStop("off")

			-- オプションボードを戻す
			if(songselectoption_:GetOpenOptionFlag())then
				songselectoption_:Tween_SlideOut()
			end
			
			for i = 1, #this.tbl_SoloCursorMoveLabel do
				if (this.tbl_SoloCursorMoveLabel[i] == "pos_center_1") then
					table.remove(this.tbl_SoloCursorMoveLabel, i)
				end

				if (this.tbl_SoloCursorMoveLabel[i] == "pos_center_2") then
					table.remove(this.tbl_SoloCursorMoveLabel, i)
				end
			end
			
			for i = 1, #this.tbl_CourseNameLabel do
				if (this.tbl_CourseNameLabel[i] == "back") then
					table.remove(this.tbl_CourseNameLabel, i)
				end

				if (this.tbl_CourseNameLabel[i] == "option") then
					table.remove(this.tbl_CourseNameLabel, i)
				end
			end

			-- 難易度を決定していない場合の処理
			this.currentCourseIndex = 1
			this.selectIndex        = 1
			this:ResetDispCursorFrame()
			this.mc_board.main.board.player_cursor_1:GotoAndStop("pos_3")
			this:SetFocusCourseMark(1)
			this:UpdateCourseChoise(this.selectIndex)

		end,

		-- プレイヤーカーソルのイニシャライズ
		InitializePlayerCursor = function(this)
			this.mc_board.main.board.player_cursor_1.cursor:GotoAndStop("in")

			if (this.is_timeUp == false) then
				this.mc_board.main.board.player_cursor_1:GotoAndStop("pos_center_1")
			else
				this.mc_board.main.board.player_cursor_1:GotoAndStop("pos_center_3")
			end
			
			this.mc_board.main.board.player_cursor_1.cursor.player_icon:GotoAndStop("1p")
			
			this.mc_board.main.board.player_cursor_2:SetVisible(false)
			this.mc_board.main.board.panel_frame_2:SetVisible(false)
			this.mc_board.main.board.course_frame_2:SetVisible(false)
			
		end,
		
		-- 前回遊んだ難易度のカーソルに合わせる
		SetCourseCursorLastDiff = function(this)
		
			if (user_setting_data_.level == this.kCourseEasyCPP) then
				Debug.PrintString("Easy")

				this.mc_board.main.board:GotoAndStop("player_cursor_1" ,"pos_center_3")
				this.mc_board.main.board:GotoAndStop("course_frame_1", "pos_1")

			elseif (user_setting_data_.level == this.kCourseNormalCPP) then
				Debug.PrintString("Normal")

				this.mc_board.main.board:GotoAndStop("player_cursor_1" ,"pos_center_4")
				this.mc_board.main.board:GotoAndStop("course_frame_1", "pos_2")

			elseif (user_setting_data_.level == this.kCourseHardCPP) then
				Debug.PrintString("Hard")

				this.mc_board.main.board:GotoAndStop("player_cursor_1" ,"pos_center_5")
				this.mc_board.main.board:GotoAndStop("course_frame_1", "pos_3")

			elseif (user_setting_data_.level >= this.kCourseOniCPP) then
				Debug.PrintString("Oni")

				this.mc_board.main.board:GotoAndStop("player_cursor_1" ,"pos_center_6")
				this.mc_board.main.board:GotoAndStop("course_frame_1", "pos_4")

			end
		end,
		
		-- 前回遊んだ難易度をセットする
		SetCourseLevelLastPlay = function(this)

			local num = 1 
		
			if (is_CardPlayer == false) then 
				if (this.is_timeUp == false) then
					if (user_setting_data_.level == this.kCourseEasyCPP) then
						this.selectIndex        = this.kCourseEasy
						this.currentCourseIndex = this.kCourseEasy
						
					elseif (user_setting_data_.level == this.kCourseNormalCPP) then
						this.selectIndex        = this.kCourseNormal
						this.currentCourseIndex = this.kCourseNormal

					elseif (user_setting_data_.level == this.kCourseHardCPP) then
						this.selectIndex        = this.kCourseHard
						this.currentCourseIndex = this.kCourseHard

					elseif (user_setting_data_.level >= this.kCourseOniCPP) then
						this.selectIndex        = this.kCourseOni
						this.currentCourseIndex = this.kCourseOni
						
					end
				else
					if (user_setting_data_.level == this.kCourseEasyCPP) then
						this.selectIndex        = this.kCourseEasyTime
						this.currentCourseIndex = this.kCourseEasyTime
						
					elseif (user_setting_data_.level == this.kCourseNormalCPP) then
						this.selectIndex        = this.kCourseNormalTime
						this.currentCourseIndex = this.kCourseNormalTime

					elseif (user_setting_data_.level == this.kCourseHardCPP) then
						this.selectIndex        = this.kCourseHardTime
						this.currentCourseIndex = this.kCourseHardTime

					elseif (user_setting_data_.level >= this.kCourseOniCPP) then
						this.selectIndex        = this.kCourseOniTime
						this.currentCourseIndex = this.kCourseOniTime

					end
				end
			else
				if(this.is_timeUpOption == true)then	-- オプションタイムアップ
					if (user_setting_data_.level == this.kCourseEasyCPP) then
						this.selectIndex        = this.kCourseEasyOptionTime 
						this.currentCourseIndex = this.kCourseEasyOptionTime 

					elseif (user_setting_data_.level == this.kCourseNormalCPP) then
						this.selectIndex        = this.kCourseNormalOptionTime 
						this.currentCourseIndex = this.kCourseNormalOptionTime 

					elseif (user_setting_data_.level == this.kCourseHardCPP) then
						this.selectIndex        = this.kCourseHardOptionTime 
						this.currentCourseIndex = this.kCourseHardOptionTime 

					elseif (user_setting_data_.level >= this.kCourseOniCPP) then
						this.selectIndex        = this.kCourseOniOptionTime 
						this.currentCourseIndex = this.kCourseOniOptionTime 
						
					end
				else
					if (this.is_timeUp == false) then
	
						if (user_setting_data_.level == this.kCourseEasyCPP) then
							this.selectIndex        = this.kCourseEasyCard
							this.currentCourseIndex = this.kCourseEasyCard
	
						elseif (user_setting_data_.level == this.kCourseNormalCPP) then
							this.selectIndex        = this.kCourseNormalCard
							this.currentCourseIndex = this.kCourseNormalCard
	
						elseif (user_setting_data_.level == this.kCourseHardCPP) then
							this.selectIndex        = this.kCourseHardCard
							this.currentCourseIndex = this.kCourseHardCard
	
						elseif (user_setting_data_.level >= this.kCourseOniCPP) then
							this.selectIndex        = this.kCourseOniCard
							this.currentCourseIndex = this.kCourseOniCard
							
						end
					else
						if (user_setting_data_.level == this.kCourseEasyCPP) then
							this.selectIndex        = this.kCourseEasyCardTime
							this.currentCourseIndex = this.kCourseEasyCardTime
	
						elseif (user_setting_data_.level == this.kCourseNormalCPP) then
							this.selectIndex        = this.kCourseNormalCardTime
							this.currentCourseIndex = this.kCourseNormalCardTime
	
						elseif (user_setting_data_.level == this.kCourseHardCPP) then
							this.selectIndex        = this.kCourseHardCardTime
							this.currentCourseIndex = this.kCourseHardCardTime
	
						elseif (user_setting_data_.level >= this.kCourseOniCPP) then
							this.selectIndex        = this.kCourseOniCardTime
							this.currentCourseIndex = this.kCourseOniCardTime
							
						end
					end
				end
			end
		end,
		
		-- 2曲目以降の時のデフォルト設定
		SetDefaultCourse = function(this)
			
			-- 以下二曲目以降の設定
			if (playSongCount >= 2) then
				this:SetCourseCursorLastDiff()
				this:SetCourseLevelLastPlay()
				this:UpdateCourseChoise(this.selectIndex)
			else
				this:DispCursorFrame()
				this:UpdateCourseChoise(this.selectIndex)
			end
		end,
		
		-- フォーカスしている難易度マークを表示する
		StartFocusCourseMark = function(this)
			this.mc_board.main.board.mark_1:GotoAndPlay("start")
			this.mc_board.main.board.mark_2:GotoAndStop("init")
		end,
		
		-- フォーカスしている難易度にマークを更新する
		SetFocusCourseMark = function(this, index)
			if (this.cursorLimitFlag == false) then
				if (index == 1) then
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course", 			"none")	
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course_white", 	"none")	
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course_white_2", 	"none")
				elseif (index == 2) then
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course", 			"none")	
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course_white", 	"none")	
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course_white_2", 	"none")
				elseif (index == 3) then
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course", 			"course_1")	
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course_white", 	"course_1")	
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course_white_2", 	"course_1")
				elseif (index == 4) then
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course", 			"course_2")	
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course_white", 	"course_2")	
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course_white_2", 	"course_2")
				elseif (index == 5) then
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course", 			"course_3")	
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course_white", 	"course_3")	
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course_white_2", 	"course_3")
				elseif (index == 6) then
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course", 			"course_4")	
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course_white", 	"course_4")	
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course_white_2", 	"course_4")
				elseif (index == 7) then
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course", 			"course_5")	
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course_white", 	"course_5")	
					this.mc_board:GotoAndStop("main/board/mark_1/mark_course_white_2", 	"course_5")
				end
				
				this.mc_board.main.board.mark_1:GotoAndPlay("start")
			end
		end,
		
		-- 難易度おにを開放
		OpenOniPanel = function(this)
			
			TSound:Play("se_senkyoku_v12a","appear_oni")
			
			this.openOniFlag                   = true
			
			this.open_oni_count = 0
			
			playerOpenLevel            = kPlayerOpenOni

			this.mc_board.board.board_4:SetVisible(true)
			
			this.mc_board.main.board.player_cursor_1:SetVisible(false)
			this.mc_board.main.board.course_frame_1:SetVisible(false)
			
			this.mc_board.board.board_4:GotoAndPlay("oni_in")
			
			table.insert(this.tbl_SoloCursorMoveLabel, "pos_center_6")
			table.insert(this.tbl_CourseNameLabel, "oni")
			
			this:MoveCursor(1)
			
			this.State_:SetState("OpenOniPanel")

		end,

		-- OpenOniPanelステート終了後処理
		OniPanelChangeEnd = function(this)
			this:OpenOniPanelCursor()
		end,
		
		--　難易度おに開放時のカーソルの表示切替
		OpenOniPanelCursor = function(this)
			this.mc_board.main.board.player_cursor_1:SetVisible(true)
			this.mc_board.main.board.course_frame_1:SetVisible(true)
			
			this.currentCourseIndex = this.selectIndex
			this:ChangeOniMark()
			
			this:PlayerMoveSelect(1)
		end,
		
		--　難易度おにからおに裏へ切り替える
		TurnOniPanel = function(this)
			
			if (selectedSongData.song_isUraOpen == false) then
				return
			end
			
			this.open_ura_count = 0

			this.mc_board.main.board.player_cursor_1:SetVisible(false)
			this.mc_board.main.board.course_frame_1:SetVisible(false)
			
			if (this.turnOniFlag == false) then
				
				this.mc_CourseBoard_[4]:ChangeUraBoard()
				this.turnOniFlag = true
				TSound:Play("se_senkyoku_v12a","appear_ura")
				this.cursorLimitFlag = false
				this.State_:SetState("ChangeUraPanel")

			elseif (this.turnOniFlag == true) then
				
				this.mc_CourseBoard_[4]:ChangeOniBoard()
				this.turnOniFlag = false
				TSound:Play("se_senkyoku_v12a","appear_ura")
				this.cursorLimitFlag = false
				this.State_:SetState("ChangeOniPanel")

			end
		end,
		
		-- おにパネルを表示・回転させたときのカーソルフレーム&マークの表示
		ChangeOniMark = function(this)
		
			this.cursorLimitFla = false
			this:DispCursorFrame()
			
		end,
		
		--　おに開放・おに裏開放のカウントをリセットする
		ResetOniUraCount = function(this)
			this.open_oni_count = 0
			this.open_ura_count = 0
		end,
		
		-- 難易度の選択状態を更新
		UpdateCourseChoise = function(this, selectedCourseIndex)
			this.currentCourseIndex = selectedCourseIndex
			
			this:CourseSet()
			
			courseId 	= this.currentCourseIndex
			courseIdStr	= this.tbl_CourseNameLabel[courseId]
			
			this:DispCursorFrame()
		end,
		
		-- 最終決定直後フラグを取得する
		GetIsSelectEnd = function(this)
			return this.is_selectEnd
		end,
		
		-- 最終決定直後フラグをセットする
		SetIsSelectEnd = function(this, setFlag)
			this.is_selectEnd = setFlag
		end,

		-- 実行状態を取得する
		GetResult = function(this)
			return this.resultType
		end,
		
		-- 実行状態をセットする
		SetResultType = function(this, type)
			this.resultType = type
		end,
		
		-- タイムアップフラグをセットする
		SetTimeUpFlag = function(this, setFlag)
			this.is_timeUp = setFlag
		end,
		
		--　カーソルの表示
		DispCursorFrame = function(this)
			
			this:ResetDispCursorFrame()
			if (is_CardPlayer == false) then 
				if (this.is_timeUp == false) then	-- カードユーザーがいない and タイムアップしていない
					if (this.selectIndex == this.kCourseBack) then
						this.mc_board.main.board.course_frame_1:GotoAndStop("none")
						this:SetFocusCourseMark(1)
						this.mc_board.main.board.panel_frame_1:GotoAndStop("back")
					elseif (this.selectIndex == this.kCourseEasy) then
						this.mc_board.main.board.panel_frame_1:GotoAndStop("none")

						this:SetFocusCourseMark(3)
						this.mc_board.main.board.course_frame_1:GotoAndStop("pos_1")
					elseif (this.selectIndex == this.kCourseNormal) then
						this.mc_board.main.board.course_frame_1:GotoAndStop("pos_2")
						this:SetFocusCourseMark(4)

					elseif (this.selectIndex == this.kCourseHard) then
						this.mc_board.main.board.course_frame_1:GotoAndStop("pos_3")
						this:SetFocusCourseMark(5)

					elseif (this.selectIndex == this.kCourseOni) then
						this.mc_board.main.board.course_frame_1:GotoAndStop("pos_4")
						if (this.turnOniFlag == true) then this:SetFocusCourseMark(7)
						else this:SetFocusCourseMark(6) end
					end
				else	-- カードユーザーがいない and タイムアップしている
					if (this.selectIndex == this.kCourseEasyTime) then
						this.mc_board.main.board.course_frame_1:GotoAndStop("pos_1")
						this:SetFocusCourseMark(3)
						
					elseif (this.selectIndex == this.kCourseNormalTime) then
						this.mc_board.main.board.course_frame_1:GotoAndStop("pos_2")
						this:SetFocusCourseMark(4)
						
					elseif (this.selectIndex == this.kCourseHardTime) then
						this.mc_board.main.board.course_frame_1:GotoAndStop("pos_3")
						this:SetFocusCourseMark(5)
						
					elseif (this.selectIndex == this.kCourseOniTime) then
						this.mc_board.main.board.course_frame_1:GotoAndStop("pos_4")
						if (this.turnOniFlag == true) then this:SetFocusCourseMark(7)
						else this:SetFocusCourseMark(6) end
					end
				end
				
			else
				if (this.is_timeUpOption == true) then -- カードユーザーがいる and オプションでタイムアップした場合
					if (this.selectIndex == this.kCourseEasyOptionTime) then
						this.mc_board.main.board.panel_frame_1:GotoAndStop("none")
						this:SetFocusCourseMark(3)

						this.mc_board.main.board.course_frame_1:GotoAndStop("pos_1")
					elseif (this.selectIndex == this.kCourseNormalOptionTime) then
						this.mc_board.main.board.course_frame_1:GotoAndStop("pos_2")

						this:SetFocusCourseMark(4)
					elseif (this.selectIndex == this.kCourseHardOptionTime) then
						this.mc_board.main.board.course_frame_1:GotoAndStop("pos_3")
						this:SetFocusCourseMark(5)

					elseif (this.selectIndex == this.kCourseOniOptionTime) then
						this.mc_board.main.board.course_frame_1:GotoAndStop("pos_4")
						if (this.turnOniFlag == true) then this:SetFocusCourseMark(7)
						else this:SetFocusCourseMark(6) end

					end
				else
					if (this.is_timeUp == false) then
						if (this.selectIndex == this.kCourseBackCard) then
							this.mc_board.main.board.panel_frame_1:GotoAndStop("back")
							this:SetFocusCourseMark(1)

						elseif (this.selectIndex == this.kCourseOptionCard) then
							this.mc_board.main.board.course_frame_1:GotoAndStop("none")
							this:SetFocusCourseMark(2)
							
							this.mc_board.main.board.panel_frame_1:GotoAndStop("option")
						elseif (this.selectIndex == this.kCourseEasyCard) then
							this.mc_board.main.board.panel_frame_1:GotoAndStop("none")
							this:SetFocusCourseMark(3)
							
							this.mc_board.main.board.course_frame_1:GotoAndStop("pos_1")
						elseif (this.selectIndex == this.kCourseNormalCard) then
							this.mc_board.main.board.course_frame_1:GotoAndStop("pos_2")
							this:SetFocusCourseMark(4)

						elseif (this.selectIndex == this.kCourseHardCard) then
							this.mc_board.main.board.course_frame_1:GotoAndStop("pos_3")
							this:SetFocusCourseMark(5)

						elseif (this.selectIndex == this.kCourseOniCard) then
							this.mc_board.main.board.course_frame_1:GotoAndStop("pos_4")
							if (this.turnOniFlag == true) then this:SetFocusCourseMark(7)
							else this:SetFocusCourseMark(6) end

						end
					
					else
						if (this.selectIndex == this.kCourseOptionCardTime) then
							this.mc_board.main.board.course_frame_1:GotoAndStop("none")
							this:SetFocusCourseMark(2)
							
							this.mc_board.main.board.panel_frame_1:GotoAndStop("option")
						elseif (this.selectIndex == this.kCourseEasyCardTime) then
							this.mc_board.main.board.panel_frame_1:GotoAndStop("none")
							this:SetFocusCourseMark(3)

							this.mc_board.main.board.course_frame_1:GotoAndStop("pos_1")
						elseif (this.selectIndex == this.kCourseNormalCardTime) then
							this.mc_board.main.board.course_frame_1:GotoAndStop("pos_2")
							this:SetFocusCourseMark(4)

						elseif (this.selectIndex == this.kCourseHardCardTime) then
							this.mc_board.main.board.course_frame_1:GotoAndStop("pos_3")
							this:SetFocusCourseMark(5)

						elseif (this.selectIndex == this.kCourseOniCardTime) then
							this.mc_board.main.board.course_frame_1:GotoAndStop("pos_4")
							if (this.turnOniFlag == true) then this:SetFocusCourseMark(7)
							else this:SetFocusCourseMark(6) end

						end
					end
				end
			end
		end,
		
		-- フレームの開始
		StartCursorFrame = function(this)

			if (is_CardPlayer == false) then 
				if (this.is_timeUp == false) then	-- カードユーザーがいない and タイムアップしていない
					if (this.selectIndex == this.kCourseBack) then
						this.mc_board.main.board.panel_frame_1.frame:GotoAndPlay("in")
					elseif (this.selectIndex >= this.kCourseEasy) then
						this.mc_board.main.board.course_frame_1.frame:GotoAndPlay("in")
					end
				else	-- カードユーザーがいない and タイムアップしている
					this.mc_board.main.board.course_frame_1.frame:GotoAndPlay("in")
				end
				
			else
				if (this.is_timeUpOption == true) then -- カードユーザーがいる and オプションでタイムアップした場合
					this.mc_board.main.board.course_frame_1.frame:GotoAndPlay("in")
				else
					if (this.is_timeUp == false) then
						if (this.selectIndex <= this.kCourseOptionCard) then
							this.mc_board.main.board.panel_frame_1.frame:GotoAndPlay("in")
						elseif (this.selectIndex >= this.kCourseEasyCard) then
							this.mc_board.main.board.course_frame_1.frame:GotoAndPlay("in")
						end
					else
						if (this.selectIndex == this.kCourseOptionCardTime) then
							this.mc_board.main.board.panel_frame_1.frame:GotoAndPlay("in")
						elseif (this.selectIndex >= this.kCourseEasyCardTime) then
							this.mc_board.main.board.course_frame_1.frame:GotoAndPlay("in")
						end
					end
				end
			end
		end,
		
		--　カーソル表示を一旦消す
		ResetDispCursorFrame = function(this)
			this.mc_board.main.board.panel_frame_1:GotoAndStop("none")
			this.mc_board.main.board.course_frame_1:GotoAndStop("none")
		end,
		
		-- プレイヤーの入力状況をチェック
		CheckInput = function(this)
			
			if(is_joinPlayer[1] == true and this.is_inputEnable_1p == true) then
				-- 1Pの入力
				if (Input.GetTrigger(Input.PLAYER1_OK) or Input.GetTrigger(Input.PLAYER1_CANCEL)) then return this.INPUT_1P_DECIDE end
				if (Input.GetTrigger(Input.PLAYER1_LEFT))	then return this.INPUT_1P_LEFT end
				if (Input.GetTrigger(Input.PLAYER1_RIGHT))	then return this.INPUT_1P_RIGHT end
			end
			
			if(is_joinPlayer[2] == true and this.is_inputEnable_2p == true) then
				-- 2Pの入力
				if (Input.GetTrigger(Input.PLAYER2_OK) or Input.GetTrigger(Input.PLAYER2_CANCEL)) then return this.INPUT_2P_DECIDE end
				if (Input.GetTrigger(Input.PLAYER2_LEFT))	then return this.INPUT_2P_LEFT end
				if (Input.GetTrigger(Input.PLAYER2_RIGHT))	then return this.INPUT_2P_RIGHT end
			end
		end,
		
		-- 区間成績をリクエストするまでのカウント
		BestSectionScoreRequestCount = function(this)
			this.start_request_bestsection_cnt = this.start_request_bestsection_cnt +1
			
			if (this.start_request_bestsection_cnt >= this.wait_request_bestsection_cnt) then
				this.start_request_bestsection_cnt = 0
				return true
			else return false
			end
		end,

		--　タイムアウト時シーケンス
		TimeUpSequence = function(this)	
			
			-- ユーザーが自分で決定していないなら自動で決定する
			if (this.is_inputEnable_1p == true) then this:CourseSet() end
			if (this.is_inputEnable_2p == true) then this:CourseSet() end
			
			-- 入力受付を切る
			this.is_inputEnable_1p = false
			this.is_inputEnable_2p = false
			
			Debug.PrintString("TimeUpSequence----------------------------")
			Debug.PrintString(this.selectIndex)
			Debug.PrintString(tostring(this.turnOniFlag))
			Debug.PrintString(tostring(this.is_timeUp))
			
			this.State_:SetState("SoloEnd")
			
			if (this.is_eraseBackPanel == false) then
				if(is_joinPlayer[1] == true) then
					if (courseId <= this.kCourseBack) then
						this.State_:SetState("CancelEnd")
					end
				elseif(is_joinPlayer[2] == true) then
					if (courseId <= this.kCourseBack) then
						this.State_:SetState("CancelEnd")
					end
				end
			end
		end,

		-- カーソルの選択が難易度の時
		-- SelectCourseEndMotion = function(this, player)
			-- if(player == this.kPlayer1)then
				-- this.mc_board.main.board.course_frame_1.frame:GotoAndPlay("choose")
				-- this.mc_board.main.board.mark_1:GotoAndPlay("course_decide_start")
				-- Don.SetLoopAnimation(0,"entry_select_loop_p1",true)
			-- else
				-- this.mc_board.main.board.course_frame_2.frame:GotoAndPlay("choose")
				-- this.mc_board.main.board.mark_2:GotoAndPlay("course_decide_start")
				-- Don.SetLoopAnimation(1,"entry_select_loop_p2",true)
			-- end
		-- end,
		
		-- オプションを開いている状態でタイムアップ
		TimeUpOptionSequence = function(this)
			this.is_timeUpOption = true
			this:EraseBoardOption()
		end,

		-- 最後に遊んだオプションを設定
		SetOptionLastDiff = function(this)
			local temp = {}
			temp[1] = user_setting_Original_data_.speed				-- 音符の速さ
			temp[2] = user_setting_Original_data_.dron				-- ドロン
			temp[3] = user_setting_Original_data_.reverse			-- あべこべ
			temp[4] = user_setting_Original_data_.randomlv			-- ランダム
			temp[5] = user_setting_Original_data_.ensoSkip			-- 演奏スキップ
			temp[6] = user_setting_Original_data_.noteDrawAdjust	-- 音符位置調整
			temp[7] = user_setting_Original_data_.voiceSkip			-- ボイススキップ
			temp[8] = user_setting_Original_data_.neiro				-- 音色

			for idx = 1, 8 do
				Debug.PrintString("鯖から落とした値："..temp[idx])
			end

			this:SetUpOptionParam(temp)
		end,

		-- オプションの設定
		SetUpSongSelectOption = function(this)
			songselectoption_:Init()
		end,

		-- オプションの値を配列で設定
		SetUpOptionParam = function(this, param)
			songselectoption_:SetPlayerOptionParamNumber(param)
		end,

		-- アイコン設定の数値を配列で取得
		GetIconParamBox = function(this)
			return songselectoption_:GetIconParamBox()
		end,

		-- オプションの使用状況(どちらかのプレイヤーがオプションにカーソルが合っている場合、trueを返します。)
		GetIsOption = function(this)
			if(this.is_timeUpOption == false)then
				if (is_CardPlayer == true) then
					if(this.is_timeUp == false) then
						if (courseId == this.kCourseOptionCard) then
							-- カーソルがオプションになっている
							return true
						end
					else
						if (courseId == this.kCourseOptionCardTime) then
							-- カーソルがオプションになっている
							return true
						end
					end
	
					if(this.is_timeUp == false) then
						if (courseId == this.kCourseOptionCard) then
							-- カーソルがオプションになっている
							return true
						end
					else
						if (courseId == this.kCourseOptionCardTime) then
							-- カーソルがオプションになっている
							return true
						end
					end
				end
			end

			if(	songselectoption_:GetOpenOptionFlag(1) == true or
				songselectoption_:GetOpenOptionFlag(2) == true)then
				return true
			end
			
			return false
		end,

		-- オプションの更新
		InitOptionIcon = function(this)
			songselectoption_:InitOptionIcon()
		end,

	}
end