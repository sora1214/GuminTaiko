AISongSelectOptionMain = {}
-- 使うクラスを読み込む
require("common.Sound")
require("ai_song_select.ai_song_select_course_board")
require("ai_song_select.ai_song_select_option_selector")

-- このクラス
function AISongSelectOptionMain.New(timer_set)
	return
	{
		LoadMovieOptionMain = function(this)
			Lumen.LoadMovie("lumen/000_default/enso_ai/song_select/ai_song_select_main_diff_option", "main/option")
			Lumen.LoadMovie("lumen/000_default/common/option", "dummy_option_icon_1p")
		end,
		
		State_ = State.New("AISongSelectOptionMain"),
		
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
		
		start_cnt = 0,
		wait_start_cnt = 0.5 * Common.FPS * timer_set,

		--------------------オプションで設定している値
		OptionParam_Player1 = {0,0,0,0,0,0,0,0},	-- オプション設定 1P側

		Option_hasNerio_Player1 = {},							-- プレイヤー1
		
		mc_OptionSelector_Left = {},
		
		mc_OptionBoard_Left = 0,
		
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

		scrollDirection 		= 0,		-- スクロール方向
		
		coursePanelIndexOffsetType = 1, 	-- 使用するオフセットテーブルの種類

		scrollType = kScrollOffsetTypeWait,
		resultType = kResultWaiting,
		
		currentOptionIndex = {1,1},			-- 選択中のジャンルIndex
		selectIndex = {1,1},
				
		kopenPanelWaitCount = 5,			-- スクロール用
		openPanelWaitCount = 0,
		
		is_inputEnable_1p = true,
		is_inputEnable_2p = true,

		isOpenOptionFlag1P = false,			-- オプションが開いているか否か

		isFadeIn1P = false,					-- フェードイン
		isFadeOut1P = false,				-- フェードアウト
		
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

					this:InitNeiro()
					--this:InitOptionIcon()
					
					for idx = 1, 8 do
						-- Player1
						this.mc_OptionSelector_Left[idx] = {}
						this.mc_OptionSelector_Left[idx] = AISongSelectOptionSelector.New(this.mc_option:GetChildMc("main/board_left/board/selector_"..idx))
						
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
						
					end

					-- 各ポップアップの表示、非表示

					-- 音符位置調整のウィンドウのmc
					local onp_l_Mc = this.mc_option:GetChildMc("main/board_left/board/onp_position_l_mc")
					local onp_l_select_Mc = this.mc_option:GetChildMc("main/board_left/board/onp_position_l_mc/onp_position_select")
					this.mc_OptionSelector_Left[this.kSelectOnpuPosition]:SetOnpuPositionMc(onp_l_Mc, onp_l_select_Mc)

					-- 演奏スキップのウィンドウのmc
					local Enso_l_Mc = this.mc_option:GetChildMc("main/board_left/board/enso_skip_l_mc")
					this.mc_OptionSelector_Left[this.kSelectSkip]:SetEnsoSkipMc(Enso_l_Mc)
					
					-- ボイスのウィンドウのmc
					local Voice_l_Mc = this.mc_option:GetChildMc("main/board_left/board/enso_voice_l_mc")
					this.mc_OptionSelector_Left[this.kSelectVoice]:SetVoiceMc(Voice_l_Mc)
					
					
					
					-- プレイヤーアイコンの設定
					-- if(is_joinRight)then
						-- local Player_icon_r_Mc = this.mc_option:GetChildMc("main/board_right/board/player_icon")
						-- local Player_icon_base_r_Mc = this.mc_option:GetChildMc("main/board_right/board/player_icon_base")
						-- Player_icon_base_r_Mc:GotoAndStop("2p")
						
						-- Player_icon_r_Mc:GotoAndStop("1p")
					-- end

					-- タイトルの設定
					this.mc_OptionBoard_Left:SetText("text_option_title","text_option_title","option_title")

					-- 音声再生スロットの設定
					this.mc_OptionSelector_Left[this.kSelectNeiro]:SetNeiroSlot(0)

					-- オプション画面の初期化
					this:PlayerOptionInit()

					-- 設定済みオプションの読み込み
					this:SetPlayerOptionParamSelector(this.OptionParam_Player1)

					-- 現在のオプションの設定を保存
					this:SaveOptionParam()
					
					this.State_:SetState("StartWait")
				end
			end

			this.State_.func_["ReLoading"] = function()
				if (Lumen.IsLoadMovieFinish() == true) then

					-- オプション画面の初期化
					this:PlayerOptionInit()

					-- 設定済みオプションの読み込み
					this:SetPlayerOptionParamSelector(this.OptionParam_Player1)
					
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
		PlayerOptionInit = function(this)
		
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
					this:PlayerOptionInit()
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
			if (this:CheckInput() == this.INPUT_1P_DECIDE or this:CheckInput() == this.INPUT_2P_DECIDE) then
				-- 面
				-- ジャンルパネル選択
				-- 選択時の処理
				-- ドンのSE
				TSound:Play("se_common_v12a","don_c")
				this:CursorMove()
				
			elseif (this:CheckInput() == this.INPUT_1P_RIGHT or this:CheckInput() == this.INPUT_2P_RIGHT) then
				-- 右ふち
				TSound:Play("se_common_v12a","katsu_l")
				this.mc_OptionSelector_Left[this.kSelectNumber_1P]:Tween_Right(this.kSelectNumber_1P)

			elseif (this:CheckInput() == this.INPUT_1P_LEFT or this:CheckInput() == this.INPUT_2P_LEFT) then
				-- 左ふち
				TSound:Play("se_common_v12a","katsu_l")
				this.mc_OptionSelector_Left[this.kSelectNumber_1P]:Tween_Left(this.kSelectNumber_1P)

			end

		end,
		
		-- カーソルを移動
		CursorMove = function(this)
			-- Player1

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

			if(this.kSelectNumber_1P > 8) then
				-- すべての項目が終わったらフェードアウト
				this:SaveOptionParam(this.kPlayer1)		-- 設定項目を保存
				this:Tween_SlideOut()
			else
				-- 次のカーソルがある場合、次のカーソルを設定
				this.mc_OptionSelector_Left[this.kSelectNumber_1P]:SetSelectCursor(true)
				this.mc_OptionSelector_Left[this.kSelectNumber_1P]:StartCursor()
			end

		end,
	
		 --フェードイン
		Tween_SlideIn = function(this)
			
			-- 操作上の初期化
			this.currentCursor = 1

			this.isFadeIn1P = true
			this.isOpenOptionFlag1P = true
			this.mc_OptionBoard_Left:GotoAndPlay("in")
			this.mc_OptionSelector_Left[1]:StartCursor()
			
		end,

		--フェードアウト
		Tween_SlideOut = function(this)
			
			-- 操作上の初期化
			this.currentCursor = 1
			Debug.PrintString("フェードアウト")
			
			this.isFadeOut1P = true
			this.mc_OptionBoard_Left:GotoAndPlay("out")
			
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
		
		-- オプション使用中フラグを設定する
		SetOpenOptionFlag = function(this, setFlag)
			this.isOpenOptionFlag1P = setFlag
		end,

		-- オプション使用中フラグを取得する
		GetOpenOptionFlag = function(this)
			return this.isOpenOptionFlag1P
		end,

		-- オプションの値を設定
		SetPlayerOptionParamNumber = function(this, param)
			Debug.PrintString("オプションの値を設定")
			for idx = 1, 8 do
				this.OptionParam_Player1[idx] = param[idx]
			end
		end,

		-- オプションの値をselectorに設定
		SetPlayerOptionParamSelector = function(this, param)
			Debug.PrintString("-----SetPlayerOptionParamSelector")
			for idx = 1, 8 do
				if(idx == 8)then
					this.mc_OptionSelector_Left[idx]:SetOptionParam(this:GetNeiroToHas(param[idx]+1))
				else
					this.mc_OptionSelector_Left[idx]:SetOptionParam(param[idx])
				end
				this.mc_OptionSelector_Left[idx]:TextSet(idx, false, this.kPlayer1)
			end
		end,

		-- 各オプションの値を保存
		-- 値は設定名、値、渡すときの数値、など
		SaveOptionParam = function(this)
			local param_1 = this:GetOptionParamName()
			local param_2 = this:GetOptionParamNumber()

			-- 保存します
			for idx = 1, 8 do
				this.OptionParam_Player1[idx] = param_2[idx]
				Debug.PrintString("オプションの値："..param_2[idx])
			end

			Debug.PrintString("プレイヤー1：設定")
			optionData_1_Speed          = param_2[1]
			optionData_1_Dron           = param_2[2]
			optionData_1_Reverse        = param_2[3]
			optionData_1_Randomlv       = param_2[4]
			optionData_1_ensoSkip       = param_2[5]
			optionData_1_noteDrawAdjust = param_2[6]
			optionData_1_voiceSkip      = param_2[7]
			optionData_1_Neiro          = param_2[8]
			
			user_setting_Original_data_.speed 			    = param_2[1]			
			user_setting_Original_data_.dron				= param_2[2]		
			user_setting_Original_data_.reverse 			= param_2[3]
			user_setting_Original_data_.randomlv			= param_2[4]
			user_setting_Original_data_.ensoSkip			= param_2[5]
			user_setting_Original_data_.noteDrawAdjust 	    = param_2[6]
			user_setting_Original_data_.voiceSkip 		    = param_2[7]
			user_setting_Original_data_.neiro 			    = param_2[8]

			Debug.PrintString("設定")
			for idx = 1, 8 do
				Debug.PrintString("設定名："..param_1[idx]..", 値："..param_2[idx])
			end

			Debug.PrintString("アイコンを取得")
			for idx2 = 1, 5 do
				Debug.PrintString("アイコン設定の際の数値："..this:GetIconParam(idx2))
			end

			--this:SetOptionIcon(player)
			this:UpdateOptionIcon()
		end,

		-- 各オプションの値を取得（文字列）
		-- return:オプションで設定した値を文字列で取得
		GetOptionParamName = function(this)
			local param = {}
			for idx = 1, 8 do
				param[idx] = this.mc_OptionSelector_Left[idx]:GetOptionItemName()
			end

			return param
		end,

		-- 各オプションの値を取得（数値）
		-- return:設定した値を数値で返す(数値は1～開始)
		GetOptionParamNumber = function(this)
			local param = {}
			for idx = 1, 8 do
				param[idx] = this.mc_OptionSelector_Left[idx]:GetOptionCurrent()
				if(idx == 8)then
					param[idx] = this:GetHasToNeiro(param[idx]+1)-1
				end
			end

			return param
		end,

		-- アイコン用の数値を配列で取得
		GetIconParamBox = function(this)
			local temp ={}
			for idx = 1, 5 do
				temp[idx] = this:GetIconParam(idx)
			end
			return temp
		end,

		-- アイコン用の数値取得処理
		GetIconParam = function(this, num)
			-- アイコン
			if(num == 1)then
				-- 速さ
				return this.OptionParam_Player1[this.kSelectSpeed]
			elseif(num == 2)then
				-- ドロン
				return this.OptionParam_Player1[this.kSelectDoron]
			elseif(num == 3)then
				-- あべこべ
				return this.OptionParam_Player1[this.kSelectAbekobe]
			elseif(num == 4)then
				-- ランダム
				return this.OptionParam_Player1[this.kSelectRandam]
			elseif(num == 5)then
				-- 音符位置調整
				return this.OptionParam_Player1[this.kSelectOnpuPosition]
			end
		end,

		-- オプションアイコンの設定
		SetOptionIcon = function(this)
			
			local optionIndex = 0
			local param={}
			local optionIconMc = 0

			param = this.OptionParam_Player1
			optionIconMc = this.mc_option_icon_1p

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
			this:SetOptionIcon()
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
			
			count = 1
			for idx = 1, #this.tbl_Label[8] do
				local flag = PlayDataManager.HasTone(1,idx-1)
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

			Debug.PrintString("-----InitNeiro")
		end,

		-- has -> neiro
		-- return neiro
		GetHasToNeiro = function(this, idx)
			Debug.PrintString("-----GetHasToNeiro")
			local num = 1

			for i = 1, #this.tbl_Label[8] do
				if(this.Option_hasNerio_Player1[idx] == this.tbl_Label[8][i])then
					num = i
				end
			end

			return num
		end,

		-- neiro -> has
		-- return has
		GetNeiroToHas = function(this, idx)
			Debug.PrintString("-----GetNeiroToHas")
			local num = 1

			if(idx == 0)then
				idx = 1
			end

			for i = 1, #this.Option_hasNerio_Player1 do
				if(this.Option_hasNerio_Player1[i] == this.tbl_Label[8][idx])then
					num = i
				end
			end

			return num
		end,
	}
end