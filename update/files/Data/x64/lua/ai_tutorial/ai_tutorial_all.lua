-- AIバトル演奏遊び方説明画面
-- Masayuki_Teraoka@al.bandainamco.jp

-- 使うクラスを読み込む
require("common.Sound")
require("common.State")
require("common.NamePlate")

AITutorialAllMain = {
	
	AllState_ = State.New("AITutorialAllMain"),
	
	--　ネームプレート
	name_plate_             = {NamePlate.New("nameplate_instance_1"),NamePlate.New("nameplate_instance_2")},
	name_plate_1            = {NamePlate.New("nameplate_instance_scene1_1"),NamePlate.New("nameplate_instance_scene1_2")},
	name_plate_2            = {NamePlate.New("nameplate_instance_scene2_1"),NamePlate.New("nameplate_instance_scene2_2")},
	name_plate_3            = {NamePlate.New("nameplate_instance_scene3_1"),NamePlate.New("nameplate_instance_scene3_2")},
	name_plate_4            = {NamePlate.New("nameplate_instance_scene4_1"),NamePlate.New("nameplate_instance_scene4_2")},
	name_plate_5            = {NamePlate.New("nameplate_instance_scene5_1"),NamePlate.New("nameplate_instance_scene5_2")},
	name_plate_6            = {NamePlate.New("nameplate_instance_scene6_1"),NamePlate.New("nameplate_instance_scene6_2")},
	name_plate_7            = {NamePlate.New("nameplate_instance_scene7_1"),NamePlate.New("nameplate_instance_scene7_2")},

	start_cnt      	        = 0,
	wait_start_cnt 	        = 0.3 * Common.FPS,
	fps_num 				= Common.FPS / 60,	-- フレームレート計算用
	katsu_counter_        	= 0,				-- "カツ"を叩いた数

	INPUT_1P_LEFT			= 1,				-- プレイヤー/左カツ
	INPUT_1P_RIGHT			= 2,				-- プレイヤー/右カツ
	INPUT_1P_DECIDE			= 3,				-- プレイヤー/ドン
	INPUT_2P_LEFT			= 4,				-- プレイヤー/左カツ
	INPUT_2P_RIGHT			= 5,				-- プレイヤー/右カツ
	INPUT_2P_DECIDE			= 6,				-- プレイヤー/ドン
	
	skip_flag_            	= false,			-- カツ5回入力でスキップ開始か
	skip_end_flag_        	= false,			-- スキップ演出の終わりまできたか
	
	is_inputEnable 	        = false,			-- 入力可否フラグ

	-- 初期化処理
	Init = function(this)

		-- ステートマシン構築
		this.AllState_.func_["Begin"] = function()
			Debug.PrintString("Begin")

			-- ネームプレートのロード
			for idx = 1, 2 do
				this.name_plate_[idx] :LoadMovie()
				this.name_plate_1[idx] :LoadMovie()
				this.name_plate_2[idx] :LoadMovie()
				this.name_plate_3[idx] :LoadMovie()
				this.name_plate_4[idx] :LoadMovie()
				this.name_plate_5[idx] :LoadMovie()
				this.name_plate_6[idx] :LoadMovie()
				this.name_plate_7[idx] :LoadMovie()				
				
			end
			
			this.AllState_:SetState("Loading")
		end

		-- 読み込み中と完了後の処理
		this.AllState_.func_["Loading"] = function()
			if(Lumen.IsLoadMovieFinish() == true) then
				Debug.PrintString("Loading")
			
				-- ルートがメインのmc (ルートは""で取得可能)
				this.main_mc_ = Lumen.GetMovieClip("",true)

				-- どんちゃん
				this:InitDon3D()
				-- AIどん
				this:InitAIDon3D()
				
				-- ネームプレート
				this:InitNamePlate()
				
				-- テキストの設定
				-- 説明スキップ文言
				this.main_skip_message_mc_    = this.main_mc_:GetChildMc("all_skip/skip_message_instance",true)
				this.main_skip_message_tx_mc_ = this.main_skip_message_mc_:GetChildMc("skip_message_tx_instance",true)
				this.main_skip_message_tx_mc_:SetText("tx_skip_instance","tutorial_99_001")
				
				-- 難易度のテキスト
				this.main_mc_.text_course:SetText("text_course","course_easy")
				this.main_mc_.scene_1.text_course:SetText("text_course","course_easy")
				this.main_mc_.scene_2.text_course:SetText("text_course","course_easy")
				this.main_mc_.scene_3.text_course:SetText("text_course","course_easy")
				this.main_mc_.scene_4.text_course:SetText("text_course","course_easy")
				this.main_mc_.scene_5.text_course:SetText("text_course","course_easy")
				this.main_mc_.scene_6.text_course:SetText("text_course","course_easy")
				this.main_mc_.scene_7.text_course:SetText("text_course","course_easy")
				
				-- 区間名称
				this.main_mc_.section_tx_01_mc:SetText("section_text","ai_song_select_section_1")
				this.main_mc_.section_tx_02_mc:SetText("section_text","ai_song_select_section_2")

				-- 説明スキップカウント
				this.main_skip_counter_mc_ = this.main_mc_:GetChildMc("all_skip/skipCounter_instance",true)
				
				-- BGM & SE
				TSound:Play("bgm_aiintro_v12g", "tutorial_loop")
				TSound:Play("voice_aistory_v12g","howtoplay_01")

				this.AllState_:SetState("WaitStart")
			end
		end
		
		this.AllState_.func_["WaitStart"] = function()
			
			-- 開始前のウェイト
			if (this:WaitStartCnt() == true) then
				-- ルートから再生
				this.main_mc_:Play()
				
				this.AllState_:SetState("fade_in")
			end
		end
		
		this.AllState_.func_["fade_in"] = function()
			
			if(this.main_mc_:IsPlay() == false) then
				
				this:SetInputEnable(true)
				
				-- ルートをラベル"scene_01"に移す
				this.scene_mc_ = Lumen.GetMovieClip("scene_1",true)

				-- テキストウィンドウのムービークリップ取得
				this.scene_child_mc_ = this.scene_mc_:GetChildMc("txt_information_scene_1",true)
				this.scene_child_mc_:SetText("txt_information","ai_tutorial_information_1")

				this:SetSectionText(1)
				
				this.scene_mc_:GotoAndPlay(1)
				this.AllState_:SetState("scene_1")
			
			end
		end
		
		this.AllState_.func_["scene_1"] = function()
			-- stopがかかったら次のシーンに移る
			this:SoundSeScene1(this.AllState_.count_)
			this:SoundVoiceScene1(this.AllState_.count_)
			
			if(this.scene_mc_:IsPlay() == false) then
				-- ルートをラベル"scene_02"に移す
				this.main_mc_:GotoAndPlay("scene_2")
				-- 変数を次のものにする
				this.scene_mc_ = Lumen.GetMovieClip("scene_2",true)

				-- テキストウィンドウのムービークリップ取得
				this.scene_child_mc_ = this.scene_mc_:GetChildMc("txt_information_scene_2",true)
				this.scene_child_mc_:SetText("txt_information","ai_tutorial_information_2")
				
				this:SetSectionText(2)
				
				-- シーンを最初から再生する
				this.scene_mc_:GotoAndPlay(1)
				this.AllState_:SetState("scene_2")
			end
		end

		this.AllState_.func_["scene_2"] = function()
			
			this:SoundSeScene2(this.AllState_.count_)
			this:SoundVoiceScene2(this.AllState_.count_)			
			
			if(this.scene_mc_:IsPlay() == false) then
			-- ルートをラベル"scene_03"に移す
				this.main_mc_:GotoAndPlay("scene_3")
				-- 変数を次のものにする
				this.scene_mc_ = Lumen.GetMovieClip("scene_3",true)

				-- テキストウィンドウのムービークリップ取得
				this.scene_child_mc_ = this.scene_mc_:GetChildMc("txt_information_scene_3",true)
				this.scene_child_mc_:SetText("txt_information","ai_tutorial_information_3")

				this:SetSectionText(3)
				
				-- シーンを最初から再生する
				this.scene_mc_:GotoAndPlay(1)
				this.AllState_:SetState("scene_3")
			end
		end

		this.AllState_.func_["scene_3"] = function()
			
			this:SoundSeScene3(this.AllState_.count_)
			this:SoundVoiceScene3(this.AllState_.count_)

			if(this.scene_mc_:IsPlay() == false) then
			-- ルートをラベル"scene_04"に移す
				this.main_mc_:GotoAndPlay("scene_4")
				-- 変数を次のものにする
				this.scene_mc_ = Lumen.GetMovieClip("scene_4",true)

				-- テキストウィンドウのムービークリップ取得
				this.scene_child_mc_ = this.scene_mc_:GetChildMc("txt_information_scene_4",true)
				this.scene_child_mc_:SetText("txt_information","ai_tutorial_information_4")
				
				this:SetSectionText(4)
				
				-- シーンを最初から再生する
				this.scene_mc_:GotoAndPlay(1)
				this.AllState_:SetState("scene_4")
			end
		end

		this.AllState_.func_["scene_4"] = function()
			
			this:SoundSeScene4(this.AllState_.count_)
			this:SoundVoiceScene4(this.AllState_.count_)

			if(this.scene_mc_:IsPlay() == false) then
			
			-- ルートをラベル"scene_05"に移す
				this.main_mc_:GotoAndPlay("scene_5")
				-- 変数を次のものにする
				this.scene_mc_ = Lumen.GetMovieClip("scene_5",true)
				this.scene_mc_.section_bar:Play()
				-- テキストウィンドウのムービークリップ取得
				this.scene_child_mc_ = this.scene_mc_:GetChildMc("txt_information_scene_5",true)
				this.scene_child_mc_:SetText("txt_information","ai_tutorial_information_5")
				
				this:SetSectionText(5)
				
				-- シーンを最初から再生する
				this.scene_mc_:GotoAndPlay(1)
				this.AllState_:SetState("scene_5")
			end
		end

		this.AllState_.func_["scene_5"] = function()
			
			this:SetMotionScene5(this.AllState_.count_)
			this:SoundSeScene5(this.AllState_.count_)
			this:SoundVoiceScene5(this.AllState_.count_)			
			
			if(this.scene_mc_:IsPlay() == false) then
			
			-- ルートをラベル"scene_06"に移す
				this.main_mc_:GotoAndPlay("scene_6")
				-- 変数を次のものにする
				this.scene_mc_ = Lumen.GetMovieClip("scene_6",true)

				-- テキストウィンドウのムービークリップ取得
				this.scene_child_mc_ = this.scene_mc_:GetChildMc("txt_information_scene_6",true)
				this.scene_child_mc_:SetText("txt_information","ai_tutorial_information_6")
				
				this:SetSectionText(6)
				
				-- シーンを最初から再生する
				this.scene_mc_:GotoAndPlay(1)
				this.AllState_:SetState("scene_6")
			end
		end

		this.AllState_.func_["scene_6"] = function()
			
			this:SetMotionScene6(this.AllState_.count_)
			this:SoundSeScene6(this.AllState_.count_)
			this:SoundVoiceScene6(this.AllState_.count_)			
			
			if(this.scene_mc_:IsPlay() == false) then
			-- ルートをラベル"scene_07"に移す
				this.main_mc_:GotoAndStop("scene_7")
				-- 変数を次のものにする
				this.scene_mc_ = Lumen.GetMovieClip("scene_7",true)

				-- テキストウィンドウのムービークリップ取得
				this.scene_child_mc_ = this.scene_mc_:GetChildMc("txt_information_scene_7",true)
				this.scene_child_mc_:SetText("txt_information","ai_tutorial_information_7")
				
				this:SetSectionText(7)
				
				-- シーンを最初から再生する
				this.scene_mc_:GotoAndPlay(1)
				this.AllState_:SetState("scene_7")
			end
		end

		this.AllState_.func_["scene_7"] = function()
			
			this:SoundSeScene7(this.AllState_.count_)
			this:SoundVoiceScene7(this.AllState_.count_)
			
			-- 再生が終わったらEndへ
			if(this.scene_mc_:IsPlay() == false) then
				this.AllState_:SetState("End")
			end
		end
		
		-- Endシーン
		this.AllState_.func_["End"] = function()
			-- シーン終了
			Common.LuaFinish()
		end
		
	end,

	-- 毎フレームの処理
	Update = function(this)
	
		-- ステート処理
		this.AllState_:Update()

		-- スキップ入力
		this:InputKatsu()

		-- スキップ
		if(this.skip_end_flag_ == false and this.skip_flag_ == true) then
			this:Skip()
		end
	end,
	
	-- 画面表示されるまでのカウント
	WaitStartCnt = function(this)
		this.start_cnt = this.start_cnt + 1
		
		if (this.start_cnt >= this.wait_start_cnt) then
			this.start_cnt = 0
			return true
		else return false
		end
	end,
	
	-- 3Dドンのイニシャライズ
	InitDon3D = function(this)
		Debug.PrintString("InitDon3D")
	
		this.don_   = this.main_mc_:GetChildMc("don_1p",true)
		
		--Don.ChangeDonForPlayData(0,Don.kType_Don) C++側で設定するからここでは不要
		Don.SetLoopAnimation(0,"normal",false)

		Don.CameraReverse(0,false)
		this.don_:SetVisible(true)
	end,

	-- 3DAIドンのイニシャライズ
	InitAIDon3D = function(this)
		Debug.PrintString("InitAIDon3D")
		
		this.aidon_ = this.main_mc_:GetChildMc("don_2p",true)
		
		Don.ChangeDefaultDon(1,Don.kType_AI)
		Don.SetLoopAnimation(1,"normal",false)

		Don.CameraReverse(1,true)
		this.aidon_:SetVisible(true)
	end,
	
	-- ネームプレートのイニシャライズ
	InitNamePlate = function(this)
		
		-- ネームプレートの準備
		for idx = 1, 2 do
			this.name_plate_[idx]:Setup()
			this.name_plate_1[idx]:Setup()
			this.name_plate_2[idx]:Setup()
			this.name_plate_3[idx]:Setup()
			this.name_plate_4[idx]:Setup()
			this.name_plate_5[idx]:Setup()
			this.name_plate_6[idx]:Setup()
			this.name_plate_7[idx]:Setup()

		end
		
		-- AIドンのセットアップ
		this.name_plate_[2]:SetAIDon()
		this.name_plate_1[2]:SetAIDon()
		this.name_plate_2[2]:SetAIDon()
		this.name_plate_3[2]:SetAIDon()
		this.name_plate_4[2]:SetAIDon()
		this.name_plate_5[2]:SetAIDon()
		this.name_plate_6[2]:SetAIDon()
		this.name_plate_7[2]:SetAIDon()


		if (is_joinPlayer[1] == true) then
			this.name_plate_[1]:SetPlayerInfoAI(1)
			this.name_plate_1[1]:SetPlayerInfoAI(1)
			this.name_plate_2[1]:SetPlayerInfoAI(1)
			this.name_plate_3[1]:SetPlayerInfoAI(1)
			this.name_plate_4[1]:SetPlayerInfoAI(1)
			this.name_plate_5[1]:SetPlayerInfoAI(1)
			this.name_plate_6[1]:SetPlayerInfoAI(1)
			this.name_plate_7[1]:SetPlayerInfoAI(1)
			
		else
			this.name_plate_[1]:SetPlayerInfoAI(2)
			this.name_plate_1[1]:SetPlayerInfoAI(2)
			this.name_plate_2[1]:SetPlayerInfoAI(2)
			this.name_plate_3[1]:SetPlayerInfoAI(2)
			this.name_plate_4[1]:SetPlayerInfoAI(2)
			this.name_plate_5[1]:SetPlayerInfoAI(2)
			this.name_plate_6[1]:SetPlayerInfoAI(2)
			this.name_plate_7[1]:SetPlayerInfoAI(2)

		end
	end,
	
	-- 各シーンに合わせて区間周りの流し込みをセットする
	SetSectionText = function(this, section)
		
		if (section == 1) then
			
			this.scene_mc_.section_tx_01_mc:SetText("section_text","ai_song_select_section_1")
			this.scene_mc_.section_tx_02_mc:SetText("section_text","ai_song_select_section_2")
		
		elseif (section == 2) then
		
			this.scene_mc_.section_tx_01_mc:SetText("section_text","ai_song_select_section_1")
			this.scene_mc_.section_tx_02_mc:SetText("section_text","ai_song_select_section_2")

		elseif (section == 3) then
		
			this.scene_mc_.section_tx_01_mc:SetText("section_text","ai_song_select_section_1")
			this.scene_mc_.section_tx_02_mc:SetText("section_text","ai_song_select_section_2")

		elseif (section == 4) then
		
			this.scene_mc_.section_tx_01_mc:SetText("section_text","ai_song_select_section_1")
			this.scene_mc_.section_tx_02_mc:SetText("section_text","ai_song_select_section_2")

			this.scene_mc_.txt_section_song_first:SetText("txt_section_song","ai_tutorial_song_first")
			this.scene_mc_.txt_section_song_last:SetText("txt_section_song","ai_tutorial_song_last")
			
			this.scene_mc_.txt_section_1:SetText("txt_section","ai_tutorial_section_1")
			this.scene_mc_.txt_section_2:SetText("txt_section","ai_tutorial_section_2")
			this.scene_mc_.txt_section_3:SetText("txt_section","ai_tutorial_section_3")
			
		elseif (section == 5) then
			this.scene_mc_.section_tx_01_mc:SetText("section_text","ai_song_select_section_1")
			this.scene_mc_.section_tx_02_mc:SetText("section_text","ai_song_select_section_2")
			
			this.scene_mc_.section_bar.section_tx_01_mc:SetText("section_text","ai_song_select_section_1")
			this.scene_mc_.section_bar.section_tx_02_mc:SetText("section_text","ai_song_select_section_2")
			
			this.scene_mc_.txt_section_song_first:SetText("txt_section_song","ai_tutorial_song_first")
			this.scene_mc_.txt_section_song_last:SetText("txt_section_song","ai_tutorial_song_last")
			
			this.scene_mc_.txt_section_1:SetText("txt_section","ai_tutorial_section_1")
			this.scene_mc_.txt_section_2:SetText("txt_section","ai_tutorial_section_2")
			this.scene_mc_.txt_section_3:SetText("txt_section","ai_tutorial_section_3")
			
		elseif (section == 6) then
			this.scene_mc_.section_tx_01_mc:SetText("section_text","ai_song_select_section_1")
			this.scene_mc_.section_tx_02_mc:SetText("section_text","ai_song_select_section_2")
			this.scene_mc_.section_tx_03_mc:SetText("section_text","ai_song_select_section_3")	
		elseif (section == 7) then
			this.scene_mc_.section_tx_03_mc:SetText("section_text","ai_song_select_section_3")	
		end
		
	end,


	----------------------------------------
	-- スキップ
	----------------------------------------

	-- スキップ入力があった場合の処理
	InputKatsu = function(this)
			
		this.flag = false
		
		-- キー入力
		if (this:CheckInput() == this.INPUT_1P_RIGHT or this:CheckInput() == this.INPUT_2P_RIGHT) then
			Debug.PrintString("TriggeredRight")
			-- 右ふち
			this.flag = true		
			this:SkipCount()
		elseif (this:CheckInput() == this.INPUT_1P_LEFT or this:CheckInput() == this.INPUT_2P_LEFT) then
			Debug.PrintString("TriggeredLeft")
			-- 左ふち
			this.flag = true
			this:SkipCount()
		end

	end,
	
	-- スキップのカウント
	SkipCount = function(this)
		
		-- スキップアイコンの演出中ではない
		if(this.main_skip_counter_mc_:IsPlay() == false and this.skip_flag_ == false) then
			this.katsu_counter_ = this.katsu_counter_ + 1
			this.main_skip_counter_mc_:GotoAndPlay(string.format("add_%d",this.katsu_counter_))

			TSound:Play("se_common_v12a","katsu_c")

			if this.katsu_counter_ >= 5 then
				this.skip_flag_ = true
			end
		end
	end,

	-- スキップ入力が5回押された後の処理
	Skip = function(this)
		-- 演出が終了次第、EndWaitへ
		if(this.main_skip_counter_mc_:IsPlay() == false) then
			this.AllState_:SetState("End")

			this.skip_end_flag_ = true
		end
	end,
	
	-- プレイヤーの入力情報
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

	-- 音声を再生する場合
	ScorePlusSound = function(this, bank, tone)
		Debug.PrintString("DonKatsu Sound, bank = "..bank..", tone = "..tone)
		TSound:Play(bank,tone)
	end,

	-- se再生タイミング
	SoundSeScene1 = function(this, frame)
		-- 吹き出し音
		if (frame == 10 * this.fps_num) then this:ScorePlusSound("se_common_v12a","action_callout_c") end
		
		-- 着地音
		if (frame == 340 * this.fps_num) then this:ScorePlusSound("se_aienso_v12g","ready") end

	end,
	
	SoundSeScene2 = function(this, frame)
		-- 吹き出し音
		if (frame == 10 * this.fps_num) then this:ScorePlusSound("se_common_v12a","action_callout_c") end
		
		-- 打音(どんちゃん)
		if (frame == 300 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 330 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 360 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 420 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 450 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 480 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 540 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 570 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 600 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end

		-- ボイス
		if (frame == 600 * this.fps_num) then this:ScorePlusSound("voice_aistory_v12g","howtoplay_don_03") end
	end,

	SoundSeScene3 = function(this, frame)
		-- 吹き出し音
		if (frame == 10 * this.fps_num) then this:ScorePlusSound("se_common_v12a","action_callout_c") end
		
		-- 打音(AIどん)
		if (frame == 300 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 330 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 360 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 420 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 450 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 480 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 540 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 570 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 600 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end

		-- ボイス
		if (frame == 600 * this.fps_num) then this:ScorePlusSound("voice_aistory_v12g","howtoplay_don_04") end
	end,
	
	SoundSeScene4 = function(this, frame)
		-- 吹き出し音
		if (frame == 10 * this.fps_num) then this:ScorePlusSound("se_common_v12a","action_callout_c") end
	end,

	SoundSeScene5 = function(this, frame)
		
		-- 打音(どんちゃん)
		if (frame == 420 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 450 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 480 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 540 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 570 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 600 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 660 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 690 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 720 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		
		-- 区間勝利ボイス
		if (frame == 720 * this.fps_num) then this:ScorePlusSound("se_aienso_v12g","section_win") end
		
		-- ボイス
		if (frame == 720 * this.fps_num) then this:ScorePlusSound("voice_aistory_v12g","howtoplay_don_06") end
	end,

	SoundSeScene6 = function(this, frame)
		-- 吹き出し音
		if (frame == 50 * this.fps_num) then this:ScorePlusSound("se_common_v12a","action_callout_c") end
		
		-- 打音(どんちゃん)
		if (frame == 120 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 150 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 180 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 240 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 270 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 300 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		
		-- 敗北マーク表示
		if (frame == 300 * this.fps_num) then this:ScorePlusSound("se_aienso_v12g","section_lose") end
		
		-- 打音(AIどん)
		if (frame == 420 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 450 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 480 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 540 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 570 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		if (frame == 600 * this.fps_num) then this:ScorePlusSound("se_common_v12a","don_c") end
		
		-- 勝利マーク表示時
		if (frame == 600 * this.fps_num) then this:ScorePlusSound("se_aienso_v12g","section_win") end
		
		-- 区間勝利ボイス
		if (frame == 600 * this.fps_num) then this:ScorePlusSound("voice_aistory_v12g","howtoplay_don_06") end
		
		-- 曲勝利時
		if (frame == 880 * this.fps_num) then this:ScorePlusSound("se_aienso_v12g","song_win") end
		
		-- 曲勝利ボイス
		if (frame == 880 * this.fps_num) then this:ScorePlusSound("voice_aistory_v12g","howtoplay_don_07") end
	end,

	SoundSeScene7 = function(this, frame)
		-- 吹き出し音
		if (frame == 50 * this.fps_num) then this:ScorePlusSound("se_common_v12a","action_callout_c") end
	end,

	-- Voice再生タイミング
	SoundVoiceScene1 = function(this, frame)

		if (frame == 10 * this.fps_num) then TSound:Play("voice_aistory_v12g","howtoplay_02") end
	end,

	SoundVoiceScene2 = function(this, frame)

		if (frame == 10 * this.fps_num) then TSound:Play("voice_aistory_v12g","howtoplay_03") end
	end,

	SoundVoiceScene3 = function(this, frame)

		if (frame == 10 * this.fps_num) then TSound:Play("voice_aistory_v12g","howtoplay_04") end
	end,

	SoundVoiceScene4 = function(this, frame)

		if (frame == 10 * this.fps_num) then TSound:Play("voice_aistory_v12g","howtoplay_05") end
	end,

	SoundVoiceScene5 = function(this, frame)

		if (frame == 10 * this.fps_num) then TSound:Play("voice_aistory_v12g","howtoplay_06") end
	end,

	SoundVoiceScene6 = function(this, frame)

		if (frame == 50 * this.fps_num) then TSound:Play("voice_aistory_v12g","howtoplay_07") end
	end,

	SoundVoiceScene7 = function(this, frame)

		if (frame == 50 * this.fps_num) then TSound:Play("voice_aistory_v12g","howtoplay_08") end
	end,


	SetMotionScene5 = function(this, frame)
		if (frame == 770 * this.fps_num) then Don.SetNonLoopAnimation(0,"combo",false) end
	end,
	
	SetMotionScene6 = function(this, frame)
		if (frame == 350 * this.fps_num) then Don.SetNonLoopAnimation(1,"combo",false) end
		if (frame == 650 * this.fps_num) then Don.SetNonLoopAnimation(0,"combo",false) end
	end,


	-- 入力受付フラグをゲットする
	GetInputEnable = function(this)
		return this.is_inputEnable
	end,

	-- 入力受付フラグをゲットする
	SetInputEnable = function(this, type)
		this.is_inputEnable = type
	end,

}