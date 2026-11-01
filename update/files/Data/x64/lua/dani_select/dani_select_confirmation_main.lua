-- 段位選択画面.確認画面シーケンスLua
-- Masayuki_Teraoka@al.bandainamco.jp

DaniSelectConfirmationMain = {}
-- 使うクラスを読み込む
require("common.Sound")
require("dani_select.dani_select_option_main")

-- このクラス
function DaniSelectConfirmationMain.New(timer_set)
	return
	{
		State_ = State.New("DaniSelectConfirmationMain"),	-- このクラス用のStateクラスを作成
		
		-- Lumenファイルをロード
		LoadMovieConfirmationMain = function(this)
			Lumen.LoadMovie("lumen/000_default/enso_dani/dani_select/dani_select_window", "window_instance")
			
			-- オプションのセットアップが終わっていないならオプションもロードする
			if(this.is_optionSetUp == false)then
				daniselectoption_ = DaniSelectOptionMain.New(1)
				daniselectoption_:LoadMovieOptionMain()
				this.is_optionSetUp = true
			end
		end,
		
		mc_root,										-- root インスタンスのムービークリップを入れる
		mc_main,										-- root/main インスタンスのムービークリップを入れる
		
		start_input_cnt         = 0,					--　セットアップが終わってから入力が開始されるまでのカウント
		wait_input_cnt          = 0.5 * Common.FPS,		--　セットアップが終わってから入力が開始されるまでのウェイト
		
		start_se_cnt            = 0,					--　決定後にSEを鳴らすまでのカウント
		wait_se_cnt             = 0.5 * Common.FPS,		--　決定後にSEを鳴らすまでのウェイト
		
		end_decide_wait_cnt		= 0,					-- 挑戦するに決定後にEndに遷移するまでのカウント
		wait_decide_end_cnt		= 3 * Common.FPS,		-- 挑戦するに決定後にEndに遷移するまでのウェイト
		
		end_cancel_wait_cnt		= 0,					-- 挑戦しないに決定後にEndに遷移するまでのカウント
		wait_cancel_end_cnt		= 1 * Common.FPS,       -- 挑戦しないに決定後にEndに遷移するまでのウェイト
		
		INPUT_1P_LEFT			= 1,					-- プレイヤー/左カツ
		INPUT_1P_RIGHT			= 2,					-- プレイヤー/右カツ
		INPUT_1P_DECIDE			= 3,					-- プレイヤー/ドン
		INPUT_2P_LEFT			= 4,					-- プレイヤー/左カツ
		INPUT_2P_RIGHT			= 5,					-- プレイヤー/右カツ
		INPUT_2P_DECIDE			= 6,					-- プレイヤー/ドン
		
		kResultWaiting			= 1,					-- 開始待機
		kResultRunning			= 2,					-- 実行中
		kResultCanseled			= 3,					-- キャンセルされた（モード選択に戻る）
		kResultDecided			= 4,					-- 決定された（難易度選択へ進む）
		
		scrollDirection 		= 0,					-- スクロール方向
		
		resultType 				= kResultWaiting,		--　決定した結果
		
		kselectOption 			= 1,					--　オプション選択時の定数
		kselectYes 				= 2,					--　挑戦する選択時の定数
		kselectNot				= 3,					--　挑戦しない選択時の定数
		
		selectIndex 			= 3,					--　現在選択しているインデックス

		decidedIndex 			= 0,					-- 最終的に決定したインデックス

		kPlayer1				= 1,					-- 1P 側定数
		kPlayer2				= 2,					-- 2P 側定数

		is_optionSetUp 			= false,				-- オプションのセットアップが終わっているか
		is_optionEndSE			= false,				--　オプション決定時のSEを鳴らしたか
		is_daniTimeUp			= false,				--　段位を選ぶところからタイムアウトで入ってきたか
		is_timeUp				= false,				--　タイムアウトになったか
		is_inputEnable 			= false,				--　入力受付可能フラグ
		is_endFlag 				= false,				--　終了フラグ
		is_timeUpEnable			= true,					-- タイムアウト可能フラグ
		is_notYesSelect			= false,				-- 挑戦しないに選択してるフラグ
		
		Init = function(this)

			-- ステートマシンを組み立てておく、実際に実行されるのはステート処理を実行するとき
			this.State_.func_["Begin"] = function()
				-- 各種パーツ読み込み
				
				this.State_:SetState("Loading")
			end
			
			-- 各種表示物のイニシャライズ
			this.State_.func_["Loading"] = function()
				if (Lumen.IsLoadMovieFinish() == true) then
					-- ムービークリップ取得
					this.mc_root = Lumen.GetMovieClip("window_instance",true)
					this.mc_main = this.mc_root:GetChildMc("main")
					
					this.mc_main:GotoAndPlay("in_challenge")
					this:SetConfirmationText()
					this:SelectCursor(true)
					
					if (this.is_daniTimeUp == true) then
						this.selectIndex = 2
					end
					
					this:PlaySaveSE()
					this:PlayVoiceConfirmation()
					
					this.State_:SetState("StartWait")
				end
			end
			
			-- 再度シーケンスが戻った時用
			this.State_.func_["ReLoading"] = function()
				if (Lumen.IsLoadMovieFinish() == true) then
					this.mc_main:GotoAndPlay("in_challenge")
					this:SelectCursor(true)
					
					if (this.is_daniTimeUp == true) then
						this.selectIndex = 2
					end

					-- 演奏オプション
					daniselectoption_:ReStartOption()
					
					this:PlaySaveSE()
					this:PlayVoiceConfirmation()

					this.State_:SetState("Main")
				end
			end
			
			-- メインへ行く前のウェイト
			this.State_.func_["StartWait"] = function()
					
				if(this:waitCnt() == true) then
					this.State_:SetState("Main")
				end
			end
			
			-- メインシーケンス
			this.State_.func_["Main"] = function()
				
				-- プレイヤーの入力周り
				this:PlayerInput()
				
				-- オプションパネルのフェードアウト後か
				if (daniselectoption_.isFadeOut1P == true) then
					this.mc_main:GotoAndPlay("out_option")
					
					-- 記録外オプションが使われているかどうか
					if (daniselectoption_:SearchCautionOptionFlag() == true) then
						this.mc_main.window.caution_info:GotoAndPlay("on")
						IsSaveAvailable = false
					else
						this.mc_main.window.caution_info:GotoAndStop("off")
						IsSaveAvailable = true
					end
					
					-- オプション終了時のSEが鳴ったか
					if (this.is_optionEndSE == false) then
						this:PlaySaveSE()
						this.is_optionEndSE = true
					end
				end
				
				--　メインのムービークリップが動いている間はキー入力は切る
				if (this.mc_main:IsPlay() == true) then
					this:SetInputEnable(false)
				else
					this:SetInputEnable(true)
				end
			end
			
			-- タイムアウト時シーケンス
			this.State_.func_["Timeup"] = function()
				
				this.is_timeUpEnable = false
				
				-- オプション選択時
				if (this.selectIndex == 1) then
					this:MoveCursor(1)
					this:SelectCursor(false)
					this.is_notYesSelect = true
					
				-- 挑戦しない選択時
				elseif (this.selectIndex == 3) then
					this:MoveCursor(-1)
					this:SelectCursor(false)
					this.is_notYesSelect = true
					
				-- 挑戦する選択時
				else
					this:PlaySeDon()
					this:SelectCursor(false)
				end
				
				this:StartButtonAnimation()
				this.decidedIndex = this.selectIndex
				this:PlayVoiceDecide()
				this.State_:SetState("WaitDecide")
			end
			
			-- 挑戦する決定時のウェイト
			this.State_.func_["WaitDecide"] = function()
				
				--　挑戦する以外にフォーカスした状態でタイムアウト時
				if (this.is_timeUp == true and this.is_notYesSelect == true) then
					if (this:waitSeCnt() == true) then
						
						this:PlaySeDon()
						this.is_timeUp = false
					end
				end
				
				if (this:endDecideWaitCnt() == true) then
					this.State_:SetState("WaitEnd")
				end
			end
			
			--　挑戦しない決定時のウェイト
			this.State_.func_["WaitCancel"] = function()
				
				if (this:endCancelWaitCnt() == true) then
					this.State_:SetState("WaitEnd")
				end
			end
			
			-- 終了時の分岐ウェイト
			this.State_.func_["WaitEnd"] = function()
				
				if (this.decidedIndex == this.kselectNot) then
					this.mc_main:GotoAndPlay("cancel_challenge")

					this.State_:SetState("End")
				elseif (this.decidedIndex == this.kselectYes) then
					this.is_timeUpEnable = false
					this.State_:SetState("End")
				end
			end
			
			--　終了時シーケンス
			this.State_.func_["End"] = function()
				
				if (this.mc_main:IsPlay() == false) then
					if (this.decidedIndex == this.kselectNot) then
						this:SetResultType(this.kResultCanseled)
					else
						this:SetResultType(this.kResultDecided)
					end
				end
			end
		end,
		
	-- ここまでInit
		
		--　キー入力が可能になるまでのカウント
		waitCnt = function(this)
			this.start_input_cnt = this.start_input_cnt +1
			
			if (this.start_input_cnt >= this.wait_input_cnt) then
				this.start_input_cnt = 0
				return true
			else return false
			end
		end,
		
		--　タイムアウト時のSEを鳴らすまでのカウント
		waitSeCnt = function(this)
			this.start_se_cnt = this.start_se_cnt +1
			
			if (this.start_se_cnt >= this.wait_se_cnt) then
				this.start_se_cnt = 0
				return true
			else return false
			end
		end,
		
		--　挑戦するに決定後にEndに遷移するまでのカウント
		endDecideWaitCnt = function(this)
			this.end_decide_wait_cnt = this.end_decide_wait_cnt +1
			
			if (this.end_decide_wait_cnt >= this.wait_decide_end_cnt) then
				this.end_decide_wait_cnt = 0
				return true
			else return false
			end
		end,
		
		--　挑戦しないに決定後にEndに遷移するまでのカウント
		endCancelWaitCnt = function(this)
			this.end_cancel_wait_cnt = this.end_cancel_wait_cnt +1
			
			if (this.end_cancel_wait_cnt >= this.wait_cancel_end_cnt) then
				this.end_cancel_wait_cnt = 0
				return true
			else return false
			end
		end,
		
		--　ステートを更新
		Update = function(this)
			this.State_:Update()
			daniselectoption_.State_:Update()
		end,
		
	-- ここまでUpdate
		
		-- 再度シーケンスが戻った時用
		ReStartConfirmationSelect = function(this)
		-- ステート処理
			this.State_:SetState("ReLoading")
		end,
		
		-- プレイヤーの入力
		PlayerInput = function(this)
			
			-- オプション中なら抜ける
			if(daniselectoption_:GetOpenOptionFlag()) then
				return
			end
			
			-- キー入力
			if ((this:CheckInput() == this.INPUT_1P_DECIDE or this:CheckInput() == this.INPUT_2P_DECIDE) or this.is_timeUp == true) then
				-- 面
				this.decidedIndex = this:DecidePlayer()
				
				-- オプション選択時
				if (this.decidedIndex == this.kselectOption) then
					this.State_:SetState("Main")
					this.is_optionEndSE = false
					this.mc_main.window.button_option.cursor_frame.frame:GotoAndPlay("decide")
					this.mc_main:GotoAndPlay("in_option")
					daniselectoption_:Tween_SlideIn(this.kPlayer1)
					TSound:Play("voice_daniodai_v12e", "select_option_c")
				
				-- 挑戦する選択時
				elseif (this.decidedIndex == this.kselectYes) then
					this:StartButtonAnimation()
					this:SetEndFlag(true)
					this:PlayVoiceDecide()
					this.State_:SetState("WaitDecide")
				
				-- 挑戦しない選択時
				else
					this:StartButtonAnimation()
					this.State_:SetState("WaitCancel")
				end
				

			elseif (this:CheckInput() == this.INPUT_1P_RIGHT or this:CheckInput() == this.INPUT_2P_RIGHT) then
				Debug.PrintString("TriggeredRight")
				-- 右ふち
				this:MoveCursor(1)
				
			elseif (this:CheckInput() == this.INPUT_1P_LEFT or this:CheckInput() == this.INPUT_2P_LEFT) then
				Debug.PrintString("TriggeredLeft")
				-- 左ふち
				this:MoveCursor(-1)
			end

		end,
		
		-- 上下入力
		MoveCursor = function(this, direction)
	
			this:PlaySeKatsu()
		
			this.selectIndex = this.selectIndex + direction
			
			if (this.is_daniTimeUp == false) then
				if (this.selectIndex > this.kselectNot) then
					this.selectIndex = this.kselectNot
				
				elseif (this.selectIndex < this.kselectOption) then
					this.selectIndex = this.kselectOption
				end
				
			else
				if (this.selectIndex > this.kselectYes) then
					this.selectIndex = this.kselectYes
				
				elseif (this.selectIndex < this.kselectOption) then
					this.selectIndex = this.kselectOption
				end

			end
			
			this:SelectCursor(false)
		end,
		
		-- カーソル表示
		SelectCursor = function(this, initFlag)
			
			if (this.is_daniTimeUp == true and initFlag == true) then
				this.mc_main.window.button_select:GotoAndStop("timeout")
				return
			end
			
			if(this.selectIndex == 1) then
				this.mc_main.window.button_option.cursor_frame:GotoAndStop("on")
				
				if (this.is_daniTimeUp == true) then
					this.mc_main.window.button_select:GotoAndStop("init_timeout")
				else
					this.mc_main.window.button_select:GotoAndStop("init")				
				end
				
			elseif(this.selectIndex == 2) then
				this.mc_main.window.button_option.cursor_frame:GotoAndStop("off")
				
				if (this.is_daniTimeUp == true) then
					this.mc_main.window.button_select:GotoAndStop("timeout")
				else
					this.mc_main.window.button_select:GotoAndStop("left")				
				end
			
			elseif(this.selectIndex == 3) then
				this.mc_main.window.button_select:GotoAndStop("right")
			end
		end,
	
		-- プレイヤー決定時
		DecidePlayer = function(this)
			
			local selectedIndex = 0
			
			if(this.selectIndex == 1) then
				-- ＳＥ「小どん（中央）」
				this:PlaySeDon()
				selectedIndex = 1
			
			elseif(this.selectIndex == 2) then
				-- ＳＥ「小どん（中央）」
				this:PlaySeDon()
				selectedIndex = 2
			else
				-- ＳＥ「キャンセル」
				this:PlaySeCancel()
				selectedIndex = 3
			end
			
			-- 1:オプション
			-- 2:決定
			-- 3:戻る
			return selectedIndex
		end,
		
		-- 流し込み対応
		SetConfirmationText = function(this)
	
			this.mc_main:SetText("window/text_challenge_info","text_challenge_info", "dani_select_confirmation")
			this.mc_main:SetText("window/button_select/text_cursor_left","text_cursor", "dani_select_confirmation_decide")
			this.mc_main:SetText("window/button_select/text_cursor_right","text_cursor", "dani_select_confirmation_cancel")
			this.mc_main:SetText("window/guide/side/guide_side_txt","guide_txt", "select")
			this.mc_main:SetText("window/guide/decide/guide_decide_txt","guide_txt", "decide")
			this.mc_main:SetText("window/caution_info/text_nosave_info", "text_nosave_info", "dani_select_option_info")
		end,
		
		-- 演奏オプションボード表示制御
		SlideOutOption = function(this)

			-- オプションボードを戻す
			if(daniselectoption_:GetOpenOptionFlag(1))then
				daniselectoption_:Tween_SlideOut(1)
			end
		end,

		-- 実行状態を取得する
		GetResult = function(this)
			return this.resultType
		end,
		
		-- 実行状態をセットする
		SetResultType = function(this, type)
			this.resultType = type
		end,
		
		-- 終了フラグを取得する
		GetEndFlag = function(this)
			return this.is_endFlag
		end,
		
		-- 終了フラグをセットする
		SetEndFlag = function(this, setFlag)
			this.is_endFlag = setFlag
		end,
		
		-- プレイヤーの入力受付可能かのフラグを取得する
		GetInputEnable = function(this)
			return this.is_inputEnable
		end,
		
		-- プレイヤーの入力受付可能かのフラグをセットする
		SetInputEnable = function(this, setFlag)
			this.is_inputEnable = setFlag
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
		
		-- タイムアップフラグをセットする
		SetTimeUpFlag = function(this, setFlag)
			this.is_timeUp = setFlag
		end,

		-- 段位選択画面タイムアップフラグをセットする
		SetDaniTimeUpFlag = function(this, setFlag)
			this.is_daniTimeUp = setFlag
		end,
		
		-- オプションを開いている状態でタイムアップ
		TimeUpOptionSequence = function(this)
			this.is_timeUpOption = true
			this:SlideOutOption()
			this.mc_main:GotoAndPlay("out_option")
		end,

		-- プレイヤーの入力状況をチェック
		CheckInput = function(this)
			
			if (this:GetInputEnable() == true) then
			
				if(is_joinPlayer[1] == true) then
					-- 1Pの入力
					if (Input.GetTrigger(Input.PLAYER1_OK) or Input.GetTrigger(Input.PLAYER1_CANCEL)) then 
						return this.INPUT_1P_DECIDE 
					end
					
					if (Input.GetTrigger(Input.PLAYER1_LEFT))	then return this.INPUT_1P_LEFT end
					if (Input.GetTrigger(Input.PLAYER1_RIGHT))	then return this.INPUT_1P_RIGHT end
				end
				
				if(is_joinPlayer[2] == true) then
					-- 2Pの入力
					if (Input.GetTrigger(Input.PLAYER2_OK) or Input.GetTrigger(Input.PLAYER2_CANCEL)) 
						then return this.INPUT_2P_DECIDE 
					end
					
					if (Input.GetTrigger(Input.PLAYER2_LEFT))	then return this.INPUT_2P_LEFT end
					if (Input.GetTrigger(Input.PLAYER2_RIGHT))	then return this.INPUT_2P_RIGHT end
				end
			end
		end,
		
		-- 挑戦する挑戦しない決定直後のアニメーション
		StartButtonAnimation = function(this)
			this.mc_main.window.button_select.cursor:GotoAndPlay("decide")
			this.mc_main.window.button_select.blink:GotoAndPlay("decide")
		end,
		
		-- どんSEをエントリーによって鳴らす
		PlaySeDon = function(this)
			TSound:Play("se_common_v12a","don_c")
		end,
		
		-- カツSEをエントリーによって鳴らす
		PlaySeKatsu = function(this)
			TSound:Play("se_common_v12a","katsu_c")
		end,
		
		-- キャンセルSEをエントリーによって鳴らす		
		PlaySeCancel = function(this)
			TSound:Play("se_common_v12a","primal_cancel_c")
		end,
		
		-- 記録可能かどうかのSE
		PlaySaveSE = function(this)
			if (IsSaveAvailable == true) then
				TSound:Play("se_daniodai_v12e", "select_memorable")
			else
				TSound:Play("se_daniodai_v12e", "select_unmemolable")
			end
		end,
		
		-- 確認ボイス
		PlayVoiceConfirmation = function(this)
			TSound:Play("voice_daniodai_v12e", "select")
		end,

		-- 決定ボイス
		PlayVoiceDecide = function(this)
			TSound:Play("voice_daniodai_v12e", "decide")
		end,

		-- 最後に遊んだオプションを設定
		SetOptionLastDiff = function(this, player)
			local temp = {}
			temp[1] = user_setting_Original_data_[player].speed				-- 音符の速さ
			temp[2] = user_setting_Original_data_[player].dron				-- ドロン
			temp[3] = user_setting_Original_data_[player].reverse			-- あべこべ
			temp[4] = user_setting_Original_data_[player].randomlv			-- ランダム
			temp[5] = user_setting_Original_data_[player].ensoSkip			-- 演奏スキップ
			temp[6] = user_setting_Original_data_[player].noteDrawAdjust	-- 音符位置調整
			temp[7] = user_setting_Original_data_[player].voiceSkip			-- ボイススキップ
			temp[8] = user_setting_Original_data_[player].neiro				-- 音色
			
			-- 強制OFF対象オプション
			temp[1] = SpeedTypes.kNormal		-- 音符の速さ
			temp[2] = OptionOnOff.kOff			-- ドロン
			temp[3] = OptionOnOff.kOff			-- あべこべ
			temp[4] = OptionOnOff.kOff			-- ランダム
			temp[8] = 1

			for idx = 1, 8 do
				Debug.PrintString("鯖から落とした値："..temp[idx])
			end

			this:SetUpOptionParam(temp)
		end,

		-- オプションの設定
		SetUpDaniSelectOption = function(this)
			daniselectoption_:Init()
		end,
		
		-- オプションの値を配列で設定
		SetUpOptionParam = function(this, param)
			daniselectoption_:SetPlayerOptionParamNumber(param)
		end,
		
		-- アイコン設定の数値を配列で取得
		GetIconParamBox = function(this)
			return daniselectoption_:GetIconParamBox()
		end,

		-- オプションの使用状況(プレイヤーがオプションにカーソルが合っている場合、trueを返します。)
		GetIsOption = function(this)
			if(this.is_timeUpOption == false)then
				if(this.is_timeUp == false) then
					if (this.decidedIndex == this.kselectOption) then
						-- カーソルがオプションになっている
						return true
					end
				else
					if (this.decidedIndex == this.kselectOption) then
						-- カーソルがオプションになっている
						return true
					end
				end	
			end

			if(daniselectoption_:GetOpenOptionFlag() == true)then
				return true
			end
			
			return false
		end,
		
		-- オプションの更新
		InitOptionIcon = function(this)
			daniselectoption_:InitOptionIcon()
		end,

		-- タイムアウトフラグを建てる
		TimeUpBegin = function(this)			
			this:SetTimeUpFlag(true)
			this:SetEndFlag(true)
			this.State_:SetState("Timeup")
		end,
	}
end