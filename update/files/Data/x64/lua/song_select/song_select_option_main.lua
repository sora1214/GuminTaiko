SongSelectOptionMain = {}
-- 使うクラスを読み込む
require("common.Sound")
--require("song_select.song_select_course_disp_data")
require("song_select.song_select_course_board")
require("song_select.song_select_option_selector")

-- このクラス
function SongSelectOptionMain.New(timer_set)
	return
	{
		LoadMovieOptionMain = function(this)
			Lumen.LoadMovie("lumen/000_default/enso_normal/song_select/song_select_main_diff_option", "main/option")
			Lumen.LoadMovie("lumen/000_default/common/option", "dummy_option_icon_1p")
			Lumen.LoadMovie("lumen/000_default/common/option", "dummy_option_icon_2p")

		end,
		
		State_ = State.New("SongSelectOptionMain"),
		
		tbl_Label = {
			{"1.0", "1.1", "1.2", "1.3", "1.4", "1.5", "1.6", "1.7", "1.8", "1.9", "2.0", "2.5", "3.0", "3.5","4.0"},	-- 音符のはやさ
			{"option_off", "option_on"},																				-- ドロン
			{"option_off", "option_on"},																				-- あべこべ
			{"option_off", "kimagure", "detarame"},																		-- ランダム
			{"option_off", "option_on"},																				-- 演奏スキップ
			{"option_off", "option_on"},																				-- 音符位置調整
			{"option_yes", "option_no"},																				-- ボイス
			{"neiro_taiko", "neiro_maturi", "neiro_inuneko", "neiro_wonderfultaiko", "neiro_drum", "neiro_tambourine",	-- 音色
			"neiro_wadadon", "neiro_clapping", "neiro_conga", "neiro_8bittaiko","neiro_soya","neiro_mekadon",
			"neiro_funassyi","neiro_wrap", "neiro_isogai", "neiro_akemi", "neiro_synthdrum","neiro_shuriken",
			"neiro_puchipuchi", "neiro_electric guitar"},
		},

		tbl_SpeedLabel 			= {"1.0", "1.1", "1.2", "1.3", "1.4", "1.5", "1.6", "1.7", "1.8", "1.9", "2.0", "2.5", "3.0", "3.5","4.0"},
		tbl_DoronLabel 			= {"off", "on"},
		tbl_AbeKobeLabel 		= {"off", "on"},
		tbl_RandomLabel 		= {"off", "kimagure", "detarame"},
		tbl_VoiceLabel 			= {"on", "off"},
		tbl_NeiroLabel 			= {"off", "on"},
		tbl_OnpuPositionLabel	= {"off", "on"},
		tbl_PositionParamLabel	= {"-10", "-9","-8","-7","-6","-5","-4","-3","-2","-1","0","1", "2","3","4","5","6","7","8","9","10"},
		tbl_EnsoSkipLabel		= {"off", "on"},
		
		start_cnt = 0,
		wait_start_cnt = 0.5 * Common.FPS * timer_set,

		--------------------オプションで設定している値
		OptionParam_Player1 = {0,0,0,0,0,0,0,0},	-- オプション設定 1P側
		OptionParam_Player2 = {0,0,0,0,0,0,0,0},	-- オプション設定 2P側

		OptionOnpu_Player1 = 1,						-- プレイヤーの音符位置 1P側
		OptionOnpu_Player2 = 1,						-- プレイヤーの音符位置 2P側

		Option_hasNerio_Player1 = {},							-- プレイヤー1
		Option_hasNerio_Player2 = {},							-- プレイヤー2
		
		mc_OptionSelector_Left = {},
		mc_OptionSelector_Right = {},
		
		mc_OptionBoard_Left = 0,
		mc_OptionBoard_Right = 0,

		mc_option_icon_Left = 0,
		mc_option_icon_Right = 0,
		
		currentCursor = 1,
		
		INPUT_1P_LEFT			= 1,		-- プレイヤー/左カツ
		INPUT_1P_RIGHT			= 2,		-- プレイヤー/右カツ
		INPUT_1P_DECIDE			= 3,		-- プレイヤー/ドン
		INPUT_2P_LEFT			= 4,		-- プレイヤー/左カツ
		INPUT_2P_RIGHT			= 5,		-- プレイヤー/右カツ
		INPUT_2P_DECIDE			= 6,		-- プレイヤー/ドン
		
		kPlayer1				= 1,		-- 1P
		kPlayer2				= 2,		-- 2P
		
		kScrollOffsetTypeWait	= 1,		-- 待機
		kScrollOffsetTypeMoveR	= 2,		-- 右へ移動＝右の難易度を選択。
		kScrollOffsetTypeMoveL	= 3,		-- 左へ移動＝左の難易度を選択。
		
		kResultWaiting			= 1,		-- 開始待機
		kResultRunning			= 2,		-- 実行中
		kResultDecided			= 3,		-- 決定された（難易度選択へ戻る

		kSelectSpeed			= 1,		-- 音符のはやさ
		kSelectDoron			= 2,		-- ドロン
		kSelectAbekobe			= 3,		-- あべこべ
		kSelectRandam			= 4,		-- ランダム
		kSelectSkip				= 5,		-- スキップ
		kSelectOnpuPosition		= 6,		-- 音符位置調整
		kSelectVoice			= 7,		-- ボイス
		kSelectNeiro			= 8,		-- 音色
		
		kSelectNumber_1P		= 1,		-- 選択中のオプション
		kSelectNumber_2P		= 1,

		scrollDirection 		= 0,		-- スクロール方向
		
		coursePanelIndexOffsetType = 1, 	-- 使用するオフセットテーブルの種類

		scrollType = kScrollOffsetTypeWait,
		resultType = kResultWaiting,
		
		currentOptionIndex = {1,1},			-- 選択中のジャンルIndex
		selectIndex = {1,1},
				
		kopenPanelWaitCount = 5,			-- スクロール用
		openPanelWaitCount = 0,
		
		selectedCourseFlag1P = false,
		selectedCourseFlag2P = false,
		
		is_inputEnable_1p = true,
		is_inputEnable_2p = true,

		isOpenOptionFlag1P = false,			-- オプションが開いているか否か
		isOpenOptionFlag2P = false,

		isFadeIn1P = false,					-- フェードイン
		isFadeIn2P = false,

		isFadeOut1P = false,				-- フェードアウト
		isFadeOut2P = false,
		
		Init = function(this)

			-- ステートマシンを組み立てておく、実際に実行されるのはステート処理を実行するとき
			this.State_.func_["Begin"] = function()
				-- 各種パーツ読み込み
				if (Lumen.IsLoadMovieFinish() == true) then
					this.State_:SetState("Loading")
				end
			end
			
			this.State_.func_["Loading"] = function()
				if (Lumen.IsLoadMovieFinish() == true) then
					Debug.PrintString("ローディング")
					-- ムービークリップ取得
					this.mc_main = Lumen.GetMovieClip("main",true)
					this.mc_option = Lumen.GetMovieClip("main/option",true)		-- ルートのMCからツリーを全部書く
					
					this.mc_OptionBoard_Left = this.mc_option:GetChildMc("main/board_left")
					this.mc_OptionBoard_Right = this.mc_option:GetChildMc("main/board_right")

					this:InitNeiro()
					--this:InitOptionIcon()
					
					for idx = 1, 8 do
						-- Player1
						this.mc_OptionSelector_Left[idx] = {}
						this.mc_OptionSelector_Left[idx] = SongSelectOptionSelector.New(this.mc_option:GetChildMc("main/board_left/board/selector_"..idx))
						
						-- 矢印
						arrow_l = this.mc_option:GetChildMc("main/board_left/board/selector_"..idx.."/arrow_left")
						arrow_r = this.mc_option:GetChildMc("main/board_left/board/selector_"..idx.."/arrow_right")
						this.mc_OptionSelector_Left[idx]:SetSelectArrowMc(arrow_l, arrow_r)
						
						-- 初期化
						if(idx == this.kSelectNeiro)then
							this.mc_OptionSelector_Left[idx]:SetNeiroAll(this.tbl_Label[idx])
							this.mc_OptionSelector_Left[idx]:Init(idx, this.Option_hasNerio_Player1)
						else
							this.mc_OptionSelector_Left[idx]:Init(idx, this.tbl_Label[idx])
						end
						
						-- Player2
						this.mc_OptionSelector_Right[idx] = {}
						this.mc_OptionSelector_Right[idx] = SongSelectOptionSelector.New(this.mc_option:GetChildMc("main/board_right/board/selector_"..idx))

						-- 矢印
						arrow_l = this.mc_option:GetChildMc("main/board_right/board/selector_"..idx.."/arrow_left")
						arrow_r = this.mc_option:GetChildMc("main/board_right/board/selector_"..idx.."/arrow_right")
						this.mc_OptionSelector_Right[idx]:SetSelectArrowMc(arrow_l, arrow_r)

						-- 初期化
						if(idx == this.kSelectNeiro)then
							this.mc_OptionSelector_Right[idx]:SetNeiroAll(this.tbl_Label[idx])
							this.mc_OptionSelector_Right[idx]:Init(idx, this.Option_hasNerio_Player2)
						else
							this.mc_OptionSelector_Right[idx]:Init(idx, this.tbl_Label[idx])
						end
						
					end

					-- 各ポップアップの表示、非表示

					-- 音符位置調整のウィンドウのmc
					local onp_l_Mc = this.mc_option:GetChildMc("main/board_left/board/onp_position_l_mc")
					local onp_l_select_Mc = this.mc_option:GetChildMc("main/board_left/board/onp_position_l_mc/onp_position_select")
					this.mc_OptionSelector_Left[this.kSelectOnpuPosition]:SetOnpuPositionMc(onp_l_Mc, onp_l_select_Mc)
					local onp_r_Mc = this.mc_option:GetChildMc("main/board_right/board/onp_position_r_mc")
					local onp_r_select_Mc = this.mc_option:GetChildMc("main/board_right/board/onp_position_r_mc/onp_position_select")
					this.mc_OptionSelector_Right[this.kSelectOnpuPosition]:SetOnpuPositionMc(onp_r_Mc, onp_r_select_Mc)

					-- 演奏スキップのウィンドウのmc
					local Enso_l_Mc = this.mc_option:GetChildMc("main/board_left/board/enso_skip_l_mc")
					this.mc_OptionSelector_Left[this.kSelectSkip]:SetEnsoSkipMc(Enso_l_Mc)
					local Enso_r_Mc = this.mc_option:GetChildMc("main/board_right/board/enso_skip_r_mc")
					this.mc_OptionSelector_Right[this.kSelectSkip]:SetEnsoSkipMc(Enso_r_Mc)

					-- プレイヤー数が2人なら、演奏スキップをグレーアウト
					Debug.PrintString("プレイヤー数"..player_num)
					if(player_num >= 2)then
						this.mc_OptionSelector_Left[this.kSelectSkip]:GrayOut()
						this.mc_OptionSelector_Right[this.kSelectSkip]:GrayOut()
					end

					-- プレイヤーアイコンの設定
					if(is_joinRight)then
						local Player_icon_r_Mc = this.mc_option:GetChildMc("main/board_right/board/player_icon")
						local Player_icon_base_r_Mc = this.mc_option:GetChildMc("main/board_right/board/player_icon_base")
						Player_icon_base_r_Mc:GotoAndStop("2p")
						if(player_num < 2)then
							Player_icon_r_Mc:GotoAndStop("1p")
						else
							Player_icon_r_Mc:GotoAndStop("2p")
						end
					end

					-- タイトルの設定
					this.mc_OptionBoard_Left:SetText("text_option_title","text_option_title","option_title")
					this.mc_OptionBoard_Right:SetText("text_option_title","text_option_title","option_title")

					-- 音声再生スロットの設定
					this.mc_OptionSelector_Left[this.kSelectNeiro]:SetNeiroSlot(0)
					this.mc_OptionSelector_Right[this.kSelectNeiro]:SetNeiroSlot(1)

					-- オプション画面の初期化
					this:PlayerOptionInit(this.kPlayer1)
					this:PlayerOptionInit(this.kPlayer2)

					-- 設定済みオプションの読み込み
					this:SetPlayerOptionParamSelector(this.kPlayer1, this.OptionParam_Player1)
					this:SetPlayerOptionParamSelector(this.kPlayer2, this.OptionParam_Player2)

					-- 現在のオプションの設定を保存
					this:SaveOptionParam(this.kPlayer1)
					this:SaveOptionParam(this.kPlayer2)
					
					this.State_:SetState("StartWait")
				end
			end

			this.State_.func_["ReLoading"] = function()
				if (Lumen.IsLoadMovieFinish() == true) then

					-- オプション画面の初期化
					this:PlayerOptionInit(this.kPlayer1)
					this:PlayerOptionInit(this.kPlayer2)

					-- 設定済みオプションの読み込み
					this:SetPlayerOptionParamSelector(this.kPlayer1, this.OptionParam_Player1)
					this:SetPlayerOptionParamSelector(this.kPlayer2, this.OptionParam_Player2)
					
					this.State_:SetState("StartWait")
				end
			end

			this.State_.func_["StartWait"] = function()
				this:waitCnt()
				
				if(this.wait_start_cnt <= 0) then
					
					this.State_:SetState("Main")
				end				
			end

			this.State_.func_["Main"] = function()
				this.resultType = this.kResultRunning
								
				this:Update_1P()
				this:Update_2P()
				
			end
			
		end,
		
	-- ここまでInit
		
		waitCnt = function(this)
			this.wait_start_cnt = this.wait_start_cnt -1
		end,

		Update = function(this)
			-- ステート処理
			this.State_:Update()
			
		end,
	-- ここまでUpdate
	
		ReStartOption = function(this)
		-- ステート処理
			this.State_:SetState("ReLoading")
			
		end,

		-- プレイヤー毎にオプションの初期化
		PlayerOptionInit = function(this, player)
			if(player == this.kPlayer1)then
				for idx = 1, 8 do
					this.mc_OptionSelector_Left[idx]:SetSelectCursor(false)
					this.mc_OptionSelector_Left[idx]:SetIsOnpuPosition(false)
				end

				this.kSelectNumber_1P = 1
				this.mc_OptionSelector_Left[this.kSelectNumber_1P]:SetSelectCursor(true)

				this.isFadeOut1P = false
				this.isOpenOptionFlag1P = false
				this.mc_OptionBoard_Left:GotoAndStop("in")

				this.mc_option:GetChildMc("main/board_left/board/skip_right"):SetVisible(false)
				this.mc_option:GetChildMc("main/board_left/board/position_right"):SetVisible(false)
				this.mc_option:GetChildMc("main/board_left/board/skip_left"):SetVisible(false)
				this.mc_option:GetChildMc("main/board_left/board/position_left"):SetVisible(false)

				this.mc_option:GetChildMc("main/board_left/board/enso_skip_r_mc"):SetVisible(false)
				this.mc_option:GetChildMc("main/board_left/board/enso_skip_l_mc"):SetVisible(false)
				this.mc_option:GetChildMc("main/board_left/board/onp_position_r_mc"):SetVisible(false)
				this.mc_option:GetChildMc("main/board_left/board/onp_position_l_mc"):SetVisible(false)
			end

			if(player == this.kPlayer2)then
				for idx = 1, 8 do
					this.mc_OptionSelector_Right[idx]:SetSelectCursor(false)
					this.mc_OptionSelector_Right[idx]:SetIsOnpuPosition(false)
				end
				this.kSelectNumber_2P = 1
				this.mc_OptionSelector_Right[this.kSelectNumber_2P]:SetSelectCursor(true)

				this.isFadeOut2P = false
				this.isOpenOptionFlag2P = false
				this.mc_OptionBoard_Right:GotoAndStop("in")

				this.mc_option:GetChildMc("main/board_right/board/skip_right"):SetVisible(false)
				this.mc_option:GetChildMc("main/board_right/board/position_right"):SetVisible(false)
				this.mc_option:GetChildMc("main/board_right/board/skip_left"):SetVisible(false)
				this.mc_option:GetChildMc("main/board_right/board/position_left"):SetVisible(false)

				this.mc_option:GetChildMc("main/board_right/board/enso_skip_r_mc"):SetVisible(false)
				this.mc_option:GetChildMc("main/board_right/board/enso_skip_l_mc"):SetVisible(false)
				this.mc_option:GetChildMc("main/board_right/board/onp_position_r_mc"):SetVisible(false)
				this.mc_option:GetChildMc("main/board_right/board/onp_position_l_mc"):SetVisible(false)
			end
		end,

		-- 左右入力
		MoveCursor = function(this, player, direction)
		
			this:SetMoveFlag(true)
			
			-- カツのSE
			TSound:Play("se_common_v12a","katsu_c")
			
			this.scrollDirection = direction;
			
			if (this.scrollDirection < 0) then 
				this:ResetOniUraCount(player)
			end
			
			this.cursorLimitFlag[player] = false
			
			this.selectIndex[player] = (this.currentCourseIndex[player] + this.scrollDirection)
			
			if (this.selectIndex[player] > #this.tbl_CourseNameLabel) then
				this.selectIndex[player] = #this.tbl_CourseNameLabel
				
				this.cursorLimitFlag[player] = true
				
				this.open_oni_count[player] = this.open_oni_count[player] + 1
				
				if(this.openOniFlag == true) then
					this.open_ura_count[player] = this.open_ura_count[player] + 1
				end
				
				if (this.open_oni_count[player] >= this.kopen_oni_count and this.openOniFlag == false) then
					this:OpenOniPanel(player)
					
				elseif(this.open_ura_count[player] >= this.kopen_ura_count and this.openOniFlag == true) then
					if (selectedSongData.course_star[5] >= 1) then this:TurnOniPanel(player) end
				end
				
			elseif (this.selectIndex[player] < 1) then
				this.cursorLimitFlag[player] = true
				this.selectIndex[player] = 1
			end
			
						
			this:UpdateCourseChoise(player, this.selectIndex[player])
			
			this:PlayerMoveSelect(player, direction)

		end,

		-- 1P毎フレーム処理
		Update_1P = function(this)
			-- フェードイン中
			if(this.isFadeIn1P) then
				if(this.mc_OptionBoard_Left:IsPlay() == false) then
					this.isFadeIn1P = false
				end
			end

			-- フェードアウト中
			if(this.isFadeOut1P) then
				if(this.mc_OptionBoard_Left:IsPlay() == false) then
					this:PlayerOptionInit(this.kPlayer1)
				end
			end

			-- オプションが開いている
			if(this.isOpenOptionFlag1P and this.isFadeIn1P == false and this.isFadeOut1P == false)then
				-- 待ちがある場合、更新しない
				if(this.mc_OptionSelector_Left[this.kSelectNumber_1P]:Wait()) then
					return
				end

				-- 現在のカーソルを更新
				this.mc_OptionSelector_Left[this.kSelectNumber_1P]:UpdateCursor()
				this:keyInput_1P()		-- キー入力
			end

		end,
		
		-- 1Pキー入力
		keyInput_1P = function (this)
			if (this:CheckInput() == this.INPUT_1P_DECIDE) then
				-- 面
				-- ジャンルパネル選択
				-- 選択時の処理
				-- ドンのSE
				TSound:Play("se_common_v12a","don_c")
				this:CursorMove(this.kPlayer1)
				--this.is_inputEnable_1p = false
				if (this.is_timeUp == false) then
--					if (player_num < 2 and courseId[this.kPlayer1] > this.kCourseBack) then 					
--					elseif (courseId[this.kPlayer1] <= this.kCourseBack and this.is_timeUp == false) then
--						this.State_:SetState("SoloCancelEnd")
--					elseif (player_num >= 2 and courseId[this.kPlayer1] > this.kCourseBack) then
--						this.selectedCourseFlag1P = true
--					end
--					this:Tween_SlideOut(this.kPlayer1)
				else
--					if (player_num < 2 and courseId[this.kPlayer1] >= this.kCourseEasyTime) then 
--						this.State_:SetState("SoloEnd")					
--					elseif (player_num >= 2 and courseId[this.kPlayer1] >= this.kCourseEasyTime) then
--						this.selectedCourseFlag1P = true
--					end
--					this:Tween_SlideOut(this.kPlayer1)
				end
				
			elseif (this:CheckInput() == this.INPUT_1P_RIGHT) then
				-- 右ふち
				TSound:Play("se_common_v12a","katsu_l")
				this.mc_OptionSelector_Left[this.kSelectNumber_1P]:Tween_Right(this.kSelectNumber_1P)

			elseif (this:CheckInput() == this.INPUT_1P_LEFT) then
				-- 左ふち
				TSound:Play("se_common_v12a","katsu_l")
				this.mc_OptionSelector_Left[this.kSelectNumber_1P]:Tween_Left(this.kSelectNumber_1P)

			end

		end,
		
		-- 2P毎フレーム処理
		Update_2P = function(this)
			-- フェードイン中
			if(this.isFadeIn2P) then
				if(this.mc_OptionBoard_Right:IsPlay() == false) then
					this.isFadeIn2P = false
				end
			end

			-- フェードアウト中
			if(this.isFadeOut2P) then
				if(this.mc_OptionBoard_Right:IsPlay() == false) then
					this:PlayerOptionInit(this.kPlayer2)
				end
			end

			-- オプションが開いている
			if(this.isOpenOptionFlag2P and this.isFadeIn2P == false and this.isFadeOut2P == false)then
				-- 待ちがある場合、更新しない
				if(this.mc_OptionSelector_Right[this.kSelectNumber_2P]:Wait()) then
					return
				end

				-- 現在のカーソルを更新
				this.mc_OptionSelector_Right[this.kSelectNumber_2P]:UpdateCursor()
				this:keyInput_2P()
			end

		end,

		-- 2Pキー入力
		keyInput_2P = function (this)
			
			if (this:CheckInput() == this.INPUT_2P_DECIDE) then
				-- 面
				
				-- ドンのSE
				TSound:Play("se_common_v12a","don_r")
				this:CursorMove(this.kPlayer2)
--				this.is_inputEnable_2p = false

				if (this.is_timeUp == false) then

--					if (player_num < 2 and courseId[this.kPlayer2] > this.kCourseBack) then 
--						this.State_:SetState("SoloEnd")
--						
--					elseif (courseId[this.kPlayer2] <= this.kCourseBack and this.is_timeUp == false) then
--						this.State_:SetState("SoloCancelEnd")
--					elseif (player_num >= 2 and courseId[this.kPlayer2] > this.kCourseBack) then
--						this.selectedCourseFlag2P = true
--					end
--					this:Tween_SlideOut(this.kPlayer2)
				else
--					if (player_num < 2 and courseId[this.kPlayer2] >= this.kCourseEasyTime) then 
--						this.State_:SetState("SoloEnd")					
--					elseif (player_num >= 2 and courseId[this.kPlayer2] >= this.kCourseEasyTime) then
--						this.selectedCourseFlag2P = true
--					end
--					this:Tween_SlideOut(this.kPlayer2)
				end
				
			elseif (this:CheckInput() == this.INPUT_2P_RIGHT) then
				-- 右ふち
				TSound:Play("se_common_v12a","katsu_r")
				this.mc_OptionSelector_Right[this.kSelectNumber_2P]:Tween_Right(this.kSelectNumber_2P)
				
			elseif (this:CheckInput() == this.INPUT_2P_LEFT) then
				-- 左ふち
				TSound:Play("se_common_v12a","katsu_r")
				this.mc_OptionSelector_Right[this.kSelectNumber_2P]:Tween_Left(this.kSelectNumber_2P)
				
			end
		end,

		PlayerMoveSelect = function(this, player, direction)
						
			if (player == this.kPlayer1) then
				Debug.PrintString("55")
				-- カーソルが限界まで到達してないならカーソルのアニメーションを動かす
				if (this.cursorLimitFlag[player] == false) then 
					this.mc_board.main.board.player_cursor_1.cursor:GotoAndPlay("move")
				end

				-- 移動方向によって難易度板のindexの対応テーブルを切り替え、アニメさせる(1P)
				if (direction < 0) then
					this.coursePanelIndexOffsetType = this.kScrollOffsetTypeMoveR
					if (player_num >= 2 and this.selectIndex[this.kPlayer1] == this.selectIndex[this.kPlayer2]) then 
						this.mc_board.main.board.player_cursor_1:GotoAndStop(this.tbl_DuoCursorMoveLabel[this.currentCourseIndex[player]])				
					else
						this.mc_board.main.board.player_cursor_1:GotoAndStop(this.tbl_SoloCursorMoveLabel[this.currentCourseIndex[player]])
					end
				else
					this.coursePanelIndexOffsetType = this.kScrollOffsetTypeMoveL
					
					if (player_num >= 2 and this.selectIndex[this.kPlayer1] == this.selectIndex[this.kPlayer2]) then 
						this.mc_board.main.board.player_cursor_1:GotoAndStop(this.tbl_DuoCursorMoveLabel[this.currentCourseIndex[player]])
					else						
						this.mc_board.main.board.player_cursor_1:GotoAndStop(this.tbl_SoloCursorMoveLabel[this.currentCourseIndex[player]])
					end
				end				
			end
		end,
								
		-- プレイヤーカーソルのイニシャライズ
		InitializePlayerCursor = function(this)
			
		end,

		-- カーソルを移動
		CursorMove = function(this, player_)
			-- Player1
			if(player_ == this.kPlayer1) then

				if(this.kSelectNumber_1P == this.kSelectOnpuPosition) then
				-- 音符位置調整

					if( this.mc_OptionSelector_Left[this.kSelectNumber_1P]:GetOptionItemName() == "option_on"
					and this.mc_OptionSelector_Left[this.kSelectNumber_1P]:GetIsOnpuPosition() == false) then
						-- 音符位置調整のウィンドウを開く
						this.mc_OptionSelector_Left[this.kSelectNumber_1P]:OpenOnpuPosition()
						return
					end

					if( this.mc_OptionSelector_Left[this.kSelectNumber_1P]:GetOptionItemName() == "option_on"
					and this.mc_OptionSelector_Left[this.kSelectNumber_1P]:GetIsOnpuPosition() == true) then
						-- 音符位置調整のウィンドウを閉じる
						this.mc_OptionSelector_Left[this.kSelectNumber_1P]:CloseOnpuPosition()
					end
				end

				-- 現在のカーソルを一つ進める
				this.kSelectNumber_1P = this.kSelectNumber_1P + 1

				-- 一つ前のカーソルを閉じる
				this.mc_OptionSelector_Left[this.kSelectNumber_1P-1]:SetSelectCursor(false)
				this.mc_OptionSelector_Left[this.kSelectNumber_1P-1]:EndCursor()

				-- プレイヤーが二人の場合、演奏スキップの設定を飛ばす
				if(player_num >= 2 and this.kSelectNumber_1P == this.kSelectSkip)then
					this.kSelectNumber_1P = this.kSelectNumber_1P + 1
				end

				if(this.kSelectNumber_1P > 8) then
					-- すべての項目が終わったらフェードアウト
					this:SaveOptionParam(this.kPlayer1)		-- 設定項目を保存
					this:Tween_SlideOut(this.kPlayer1)
				else
					-- 次のカーソルがある場合、次のカーソルを設定
					this.mc_OptionSelector_Left[this.kSelectNumber_1P]:SetSelectCursor(true)
					this.mc_OptionSelector_Left[this.kSelectNumber_1P]:StartCursor()
				end
			end

			-- Player2
			if(player_ == this.kPlayer2) then
				if(this.kSelectNumber_2P == this.kSelectOnpuPosition) then
					-- 音符位置調整

					if( this.mc_OptionSelector_Right[this.kSelectNumber_2P]:GetOptionItemName() == "option_on"
					and this.mc_OptionSelector_Right[this.kSelectNumber_2P]:GetIsOnpuPosition() == false) then
						-- 音符位置調整のウィンドウを開く
						this.mc_OptionSelector_Right[this.kSelectNumber_2P]:OpenOnpuPosition()
						return
					end

					if( this.mc_OptionSelector_Right[this.kSelectNumber_2P]:GetOptionItemName() == "option_on"
					and this.mc_OptionSelector_Right[this.kSelectNumber_2P]:GetIsOnpuPosition() == true) then
						-- 音符位置調整のウィンドウを閉じる
						this.mc_OptionSelector_Right[this.kSelectNumber_2P]:CloseOnpuPosition()
					end
				end

				-- 現在のカーソルを一つ進める
				this.kSelectNumber_2P = this.kSelectNumber_2P + 1

				-- 一つ前のカーソルを閉じる
				this.mc_OptionSelector_Right[this.kSelectNumber_2P-1]:SetSelectCursor(false)
				this.mc_OptionSelector_Right[this.kSelectNumber_2P-1]:EndCursor()

				-- プレイヤーが二人の場合、演奏スキップの設定を飛ばす
				if(player_num >= 2 and this.kSelectNumber_2P == this.kSelectSkip)then
					this.kSelectNumber_2P = this.kSelectNumber_2P + 1
				end

				if(this.kSelectNumber_2P > 8) then
					-- すべての項目が終わったらフェードアウト
					this:SaveOptionParam(this.kPlayer2)		-- 設定項目を保存
					this:Tween_SlideOut(this.kPlayer2)
				else
					this.mc_OptionSelector_Right[this.kSelectNumber_2P]:SetSelectCursor(true)
					this.mc_OptionSelector_Right[this.kSelectNumber_2P]:StartCursor()
				end
			end
		end,
	
		 --フェードイン
		Tween_SlideIn = function(this, player_)
					
			-- 操作上の初期化
			this.currentCursor = 1

			if (player_ == this.kPlayer1) then
				
				this.isFadeIn1P = true
				this.isOpenOptionFlag1P = true
				this.mc_OptionBoard_Left:GotoAndPlay("in")
				this.mc_OptionSelector_Left[1]:StartCursor()
			else 
				this.isFadeIn2P = true
				this.isOpenOptionFlag2P = true
				this.mc_OptionBoard_Right:GotoAndPlay("in")
				this.mc_OptionSelector_Right[1]:StartCursor()
			end
			
		end,

		--フェードアウト
		Tween_SlideOut = function(this, player_)
					
			-- 操作上の初期化
			this.currentCursor = 1
			Debug.PrintString("フェードアウト")
			if (player_ == this.kPlayer1) then 
				this.isFadeOut1P = true
				this.mc_OptionBoard_Left:GotoAndPlay("out")
			else 
				this.isFadeOut2P = true
				this.mc_OptionBoard_Right:GotoAndPlay("out")
			end
			
		end,

		-- 演出待ちの処理
		PlayerWait = function(this, player)
			-- 待ちがある場合、trueを返す
--			return false
		end,
		
		-- 難易度の選択状態を更新
		UpdateCourseChoise = function(this, player, selectedCourseIndex)
			
			this.currentCourseIndex[player] = selectedCourseIndex
			
			courseId[player] 	= this.currentCourseIndex[player]
			courseIdStr[player]	= this.tbl_CourseNameLabel[courseId[player]]
			
			this:DispCursorFrame(player)
		end,
		
		-- 実行状態を取得する
		GetResult = function(this)
			return this.resultType
		end,
		
		-- 実行状態をセットする
		SetResultType = function(this, type)
			this.resultType = type
		end,

		-- カーソル移動フラグを取得する
		GetMoveFlag = function(this)

			return this.cursorMoveFlag
		end,

		-- カーソル移動フラグを取得する
		SetMoveFlag = function(this, setFlag)
			this.cursorMoveFlag = setFlag
		end,
		
		-- タイムアップフラグをセットする
		SetTimeUpFlag = function(this, setFlag)
			this.is_timeUp = setFlag
		end,

		
		ResetDispCursorFrame = function(this, player)
			
			-- if (player == this.kPlayer1) then
				-- this.mc_board.main.board.panel_frame_1:GotoAndStop("none")
				-- this.mc_board.main.board.course_frame_1:GotoAndStop("none")
			-- end
			
			-- if (player == this.kPlayer2) then			
				-- this.mc_board.main.board.panel_frame_2:GotoAndStop("none")
				-- this.mc_board.main.board.course_frame_2:GotoAndStop("none")
			-- end
		end,
		
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
			-- 入力なし
			--return -1
		end,
		
		-- オプション使用中フラグを設定する
		SetOpenOptionFlag = function(this, setFlag, player)
			if(player == this.kPlayer1) then
				this.isOpenOptionFlag1P = setFlag
			end

			if(player == this.kPlayer2) then
				this.isOpenOptionFlag2P = setFlag
			end
		end,

		-- オプション使用中フラグを取得する
		GetOpenOptionFlag = function(this, player)
			if(player == this.kPlayer1) then
				return this.isOpenOptionFlag1P
			end

			if(player == this.kPlayer2) then
				return this.isOpenOptionFlag2P
			end
		end,

		-- オプションの値を設定
		SetPlayerOptionParamNumber = function(this, player, param)
			Debug.PrintString("オプションの値を設定")
			for idx = 1, 8 do
				if(player == this.kPlayer1)then
					this.OptionParam_Player1[idx] = param[idx]
				else
					this.OptionParam_Player2[idx] = param[idx]
				end
			end
		end,

		-- オプションの値をselectorに設定
		SetPlayerOptionParamSelector = function(this, player, param)
			Debug.PrintString("-----SetPlayerOptionParamSelector")
			for idx = 1, 8 do
				if(player == this.kPlayer1)then
					if(idx == 8)then
						this.mc_OptionSelector_Left[idx]:SetOptionParam(this:GetNeiroToHas(player, param[idx]+1))
					else
						this.mc_OptionSelector_Left[idx]:SetOptionParam(param[idx])
					end
					this.mc_OptionSelector_Left[idx]:TextSet(idx, false, this.kPlayer1)

				else
					if(idx == 8)then
						this.mc_OptionSelector_Right[idx]:SetOptionParam(this:GetNeiroToHas(player, param[idx]+1))
					else
						this.mc_OptionSelector_Right[idx]:SetOptionParam(param[idx])
					end

					this.mc_OptionSelector_Right[idx]:TextSet(idx, false, this.kPlayer2)

				end
			end
		end,

		-- 各オプションの値を保存
		-- 値は設定名、値、渡すときの数値、など
		SaveOptionParam = function(this, player)
			local param_1 = this:GetOptionParamName(player)
			local param_2 = this:GetOptionParamNumber(player)

			-- 保存します
			for idx = 1, 8 do
				if(player == this.kPlayer1)then
					this.OptionParam_Player1[idx] = param_2[idx]
					Debug.PrintString("オプションの値："..param_2[idx])
				else
					this.OptionParam_Player2[idx] = param_2[idx]
				end
			end

			if(player == this.kPlayer1)then
				Debug.PrintString("プレイヤー1：設定")
				optionData_1_Speed = param_2[1]
				optionData_1_Dron = param_2[2]
				optionData_1_Reverse = param_2[3]
				optionData_1_Randomlv = param_2[4]
				optionData_1_ensoSkip = param_2[5]
				optionData_1_noteDrawAdjust = param_2[6]
				optionData_1_voiceSkip = param_2[7]
				optionData_1_Neiro = param_2[8]
				
				user_setting_Original_data_[1].speed 			= param_2[1]			
				user_setting_Original_data_[1].dron				= param_2[2]		
				user_setting_Original_data_[1].reverse 			= param_2[3]
				user_setting_Original_data_[1].randomlv			= param_2[4]
				user_setting_Original_data_[1].ensoSkip			= param_2[5]
				user_setting_Original_data_[1].noteDrawAdjust 	= param_2[6]
				user_setting_Original_data_[1].voiceSkip 		= param_2[7]
				user_setting_Original_data_[1].neiro 			= param_2[8]
					
			else
				Debug.PrintString("プレイヤー2：設定")
				optionData_2_Speed = param_2[1]
				optionData_2_Dron = param_2[2]
				optionData_2_Reverse = param_2[3]
				optionData_2_Randomlv = param_2[4]
				optionData_2_ensoSkip = param_2[5]
				optionData_2_noteDrawAdjust = param_2[6]
				optionData_2_voiceSkip = param_2[7]
				optionData_2_Neiro = param_2[8]
				
				user_setting_Original_data_[2].speed 			= param_2[1]			
				user_setting_Original_data_[2].dron				= param_2[2]		
				user_setting_Original_data_[2].reverse 			= param_2[3]
				user_setting_Original_data_[2].randomlv			= param_2[4]
				user_setting_Original_data_[2].ensoSkip			= param_2[5]
				user_setting_Original_data_[2].noteDrawAdjust 	= param_2[6]
				user_setting_Original_data_[2].voiceSkip 		= param_2[7]
				user_setting_Original_data_[2].neiro 			= param_2[8]
			end

			Debug.PrintString("設定")
			for idx = 1, 8 do
				Debug.PrintString("設定名："..param_1[idx]..", 値："..param_2[idx])
			end

			Debug.PrintString("アイコンを取得")
			for idx2 = 1, 5 do
				Debug.PrintString("アイコン設定の際の数値："..this:GetIconParam(player, idx2))
			end

			--this:SetOptionIcon(player)
			this:UpdateOptionIcon()
		end,

		-- 各オプションの値を取得（文字列）
		-- return:オプションで設定した値を文字列で取得
		GetOptionParamName = function(this, player)
			local param = {}
			for idx = 1, 8 do
				if(player == this.kPlayer1)then
					param[idx] = this.mc_OptionSelector_Left[idx]:GetOptionItemName()
				else
					param[idx] = this.mc_OptionSelector_Right[idx]:GetOptionItemName()
				end
			end

			return param
		end,

		-- 各オプションの値を取得（数値）
		-- return:設定した値を数値で返す(数値は1～開始)
		GetOptionParamNumber = function(this, player)
			local param = {}
			for idx = 1, 8 do
				if(player == this.kPlayer1)then
					param[idx] = this.mc_OptionSelector_Left[idx]:GetOptionCurrent()
				else
					param[idx] = this.mc_OptionSelector_Right[idx]:GetOptionCurrent()
				end
				if(idx == 8)then
					param[idx] = this:GetHasToNeiro(player, param[idx]+1)-1
				end
			end

			return param
		end,

		-- アイコン用の数値を配列で取得
		GetIconParamBox = function(this, player)
			local temp ={}
			for idx = 1, 5 do
				temp[idx] = this:GetIconParam(player, idx)
			end
			return temp
		end,

		-- アイコン用の数値取得処理
		GetIconParam = function(this, player, num)
			-- アイコン
			if(num == 1)then
				-- 速さ
				if(player == this.kPlayer1)then
					return this.OptionParam_Player1[this.kSelectSpeed]
				else
					return this.OptionParam_Player2[this.kSelectSpeed]
				end
			elseif(num == 2)then
				-- ドロン
				if(player == this.kPlayer1)then
					return this.OptionParam_Player1[this.kSelectDoron]
				else
					return this.OptionParam_Player2[this.kSelectDoron]
				end
			elseif(num == 3)then
				-- あべこべ
				if(player == this.kPlayer1)then
					return this.OptionParam_Player1[this.kSelectAbekobe]
				else
					return this.OptionParam_Player2[this.kSelectAbekobe]
				end
			elseif(num == 4)then
				-- ランダム
				if(player == this.kPlayer1)then
					return this.OptionParam_Player1[this.kSelectRandam]
				else
					return this.OptionParam_Player2[this.kSelectRandam]
				end
			elseif(num == 5)then
				-- 音符位置調整
				if(player == this.kPlayer1)then
					return this.OptionParam_Player1[this.kSelectOnpuPosition]
				else
					return this.OptionParam_Player2[this.kSelectOnpuPosition]
				end
			end
		end,

		-- オプションアイコンの設定
		SetOptionIcon = function(this, player)
			
			local optionIndex = 0
			local param={}
			local optionIconMc = 0

			if(player == this.kPlayer1)then
				param = this.OptionParam_Player1
				optionIconMc = this.mc_option_icon_1p
			else
				param = this.OptionParam_Player2
				optionIconMc = this.mc_option_icon_2p
			end

			optionIconMc:GotoAndStop("menu")

			-- 倍速オプション
			if(param[this.kSelectSpeed] ~= 0) then
				buffStr = "option"..optionIndex
				if(player == this.kPlayer2)then buffStr = "option"..(4-optionIndex) end
				targetMc = optionIconMc.option:GetChildMc(buffStr,true)
				if(param[this.kSelectSpeed] == 1) then targetMc:GotoAndStop("speedx1.1")
				elseif(param[this.kSelectSpeed] == 2) then targetMc:GotoAndStop("speedx1.2")
				elseif(param[this.kSelectSpeed] == 3) then targetMc:GotoAndStop("speedx1.3")
				elseif(param[this.kSelectSpeed] == 4) then targetMc:GotoAndStop("speedx1.4")
				elseif(param[this.kSelectSpeed] == 5) then targetMc:GotoAndStop("speedx1.5")
				elseif(param[this.kSelectSpeed] == 6) then targetMc:GotoAndStop("speedx1.6")
				elseif(param[this.kSelectSpeed] == 7) then targetMc:GotoAndStop("speedx1.7")
				elseif(param[this.kSelectSpeed] == 8) then targetMc:GotoAndStop("speedx1.8")
				elseif(param[this.kSelectSpeed] == 9) then targetMc:GotoAndStop("speedx1.9")
				elseif(param[this.kSelectSpeed] == 10) then targetMc:GotoAndStop("speedx2")
				elseif(param[this.kSelectSpeed] == 11) then targetMc:GotoAndStop("speedx2.5")
				elseif(param[this.kSelectSpeed] == 12) then targetMc:GotoAndStop("speedx3")
				elseif(param[this.kSelectSpeed] == 13) then targetMc:GotoAndStop("speedx3.5")
				elseif(param[this.kSelectSpeed] == 14) then targetMc:GotoAndStop("speedx4")
				end
				optionIndex = optionIndex + 1
			end
			-- どろんオプション
			if(param[this.kSelectDoron] ~= 0) then
				local buffStr = "option"..optionIndex
				if(player == this.kPlayer2)then buffStr = "option"..(4-optionIndex) end
				targetMc = optionIconMc.option:GetChildMc(buffStr,true)
				targetMc:GotoAndStop("doron")
				optionIndex = optionIndex + 1
			end
			-- あべこべオプション
			if(param[this.kSelectAbekobe] ~= 0) then
				buffStr = "option"..optionIndex
				if(player == this.kPlayer2)then buffStr = "option"..(4-optionIndex) end
				targetMc = optionIconMc.option:GetChildMc(buffStr,true)
				targetMc:GotoAndStop("abekobe")
				optionIndex = optionIndex + 1
			end
			-- ランダムオプション
			if(param[this.kSelectRandam] ~= 0) then		
				buffStr = "option"..optionIndex
				if(player == this.kPlayer2)then buffStr = "option"..(4-optionIndex) end
				targetMc = optionIconMc.option:GetChildMc(buffStr,true)
				if(param[this.kSelectRandam] == 1) then targetMc:GotoAndStop("kimagure")
				elseif(param[this.kSelectRandam] == 2) then targetMc:GotoAndStop("detarame")
				end
				optionIndex = optionIndex + 1
			end	
			-- 音符表示位置調整オプション
			if(param[this.kSelectOnpuPosition] ~= 0) then		
				buffStr = "option"..optionIndex
				if(player == this.kPlayer2)then buffStr = "option"..(4-optionIndex) end
				targetMc = optionIconMc.option:GetChildMc(buffStr,true)
				targetMc:GotoAndStop("note_pos")
				optionIndex = optionIndex + 1
			end
			
			-- 表示するオプションアイコンの個数に合わせて背景画像を伸ばす
			--if(playerIndex == 1) then
			--	str = ""..optionIndex
			--	this.scoreBase1pMc_.option_icon_bg:GotoAndStop(str)
			--end
		end,

		-- オプションアイコンの初期化
		InitOptionIcon = function(this)
			this.mc_option_icon_1p = Lumen.GetMovieClip("main/dummy_option_icon_1p",true)
			this.mc_option_icon_2p = Lumen.GetMovieClip("main/dummy_option_icon_2p",true)

			-- 使わない場合は"none"を設定
			this:UpdateOptionIcon()

		end,

		-- オプションアイコンの更新
		UpdateOptionIcon = function(this)
			this.mc_option_icon_1p:GotoAndStop("menu")
			this.mc_option_icon_1p.option.option0:GotoAndStop("none")
			this.mc_option_icon_1p.option.option1:GotoAndStop("none")
			this.mc_option_icon_1p.option.option2:GotoAndStop("none")
			this.mc_option_icon_1p.option.option3:GotoAndStop("none")
			this.mc_option_icon_1p.option.option4:GotoAndStop("none")
			this:SetOptionIcon(this.kPlayer1)

			this.mc_option_icon_2p:GotoAndStop("menu")
			this.mc_option_icon_2p.option.option0:GotoAndStop("none")
			this.mc_option_icon_2p.option.option1:GotoAndStop("none")
			this.mc_option_icon_2p.option.option2:GotoAndStop("none")
			this.mc_option_icon_2p.option.option3:GotoAndStop("none")
			this.mc_option_icon_2p.option.option4:GotoAndStop("none")
			this:SetOptionIcon(this.kPlayer2)
		end,

		-- プレイヤーアイコンの設定
		InitPlayerIcon = function(this)
			local Enso_r_Mc = this.mc_option:GetChildMc("main/board_right/board/enso_skip_r_mc")
		end,

		InitNeiro =function(this)
			Debug.PrintString("-----InitNeiro")

			local count = 1
			for idx = 1, #this.tbl_Label[8] do
				local flag = PlayDataManager.HasTone(0,idx-1)
				if(flag == true)then
					Debug.PrintString("idx:"..idx..", true")
					this.Option_hasNerio_Player1[count] = this.tbl_Label[8][idx]
					count = count+1
				else
					Debug.PrintString("idx:"..idx..", false")
				end
			end

			if(#this.Option_hasNerio_Player1 == 0)then
				this.Option_hasNerio_Player1[1] = this.tbl_Label[8][1]
			end

			count = 1
			for idx = 1, #this.tbl_Label[8] do
				local flag = PlayDataManager.HasTone(1,idx-1)
				if(flag == true)then
					Debug.PrintString("idx:"..idx..", true")
					this.Option_hasNerio_Player2[count] = this.tbl_Label[8][idx]
					count = count+1
				else
					Debug.PrintString("idx:"..idx..", false")
				end
			end

			if(#this.Option_hasNerio_Player2 == 0)then
				this.Option_hasNerio_Player2[1] = this.tbl_Label[8][1]
			end

			Debug.PrintString("-----InitNeiro")
		end,

		-- has -> neiro
		-- return neiro
		GetHasToNeiro = function(this, player, idx)
			Debug.PrintString("-----GetHasToNeiro")
			local num = 1

			if(player == this.kPlayer1)then
				for i = 1, #this.tbl_Label[8] do
					if(this.Option_hasNerio_Player1[idx] == this.tbl_Label[8][i])then
						num = i
					end
				end
			end

			if(player == this.kPlayer2)then
				for i = 1, #this.tbl_Label[8] do
					if(this.Option_hasNerio_Player2[idx] == this.tbl_Label[8][i])then
						num = i
					end
				end
			end

			return num
		end,

		-- neiro -> has
		-- return has
		GetNeiroToHas = function(this, player, idx)
			Debug.PrintString("-----GetNeiroToHas")
			local num = 1

			if(idx == 0)then
				idx = 1
			end

			if(player == this.kPlayer1)then
				for i = 1, #this.Option_hasNerio_Player1 do
					if(this.Option_hasNerio_Player1[i] == this.tbl_Label[8][idx])then
						num = i
					end
				end
			end

			if(player == this.kPlayer2)then
				for i = 1, #this.Option_hasNerio_Player2 do
					if(this.Option_hasNerio_Player2[i] == this.tbl_Label[8][idx])then
						num = i
					end
				end
			end

			return num
		end,
	}
end