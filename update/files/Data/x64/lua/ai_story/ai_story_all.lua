-- AIストーリー画面.全体シーケンスLua
-- Masayuki_Teraoka@al.bandainamco.jp

-- 使うクラスを読み込む
require("common.Sound")
require("common.State")
require("ai_song_select.ai_song_select_bg")

-- このクラス
AIStoryAllMain = {

	AllState_      = State.New("AIStoryAllMain"),
	
	--　背景
	storybg_		= AISongSelectBg.New("bg_instance"),

	start_cnt      	= 0,
	wait_start_cnt 	= 1 * Common.FPS,
	
	start_input_cnt = 0,
	wait_input_cnt 	= 10 * Common.FPS,

	start_input_cut_cnt = 0,
	wait_input_cut_cnt 	= 0.5 * Common.FPS,

	--　一人プレイ時のカーソルのラベル名
	tbl_StoryPhraseLabel_1  = {"phrase0","phrase1","phrase2","phrase3","phrase4","phrase5","phrase6","phrase7","phrase8","phrase9","phrase10","phrase11","phrase12","phrase13","phrase14","phrase15"},
	tbl_StoryPhraseLabel_2  = {"phrase0","phrase1","phrase2","phrase3","phrase4","phrase5","phrase6","phrase7","phrase8","phrase9","phrase10","phrase11","phrase12","phrase13","phrase14"},
	tbl_StoryPhraseLabel_3  = {"phrase0","phrase1","phrase2","phrase3","phrase4","phrase5","phrase6","phrase7","phrase8","phrase9","phrase10","phrase11","phrase12","phrase13","phrase14","phrase15"},

	mc_main	                = 0,				--　main のMCを入れる
	mc_kaiwa                = 0,				--　main/kaiwa のMCを入れる

	kResultWaiting			= 1,				-- 開始待機
	kResultRunning			= 2,				-- 実行中
	kResultCanseled			= 3,				-- キャンセルされた
	kResultDecided			= 4,				-- 決定された（確認画面へ進む）
	kResultGatden			= 5, 				-- 外伝の開始
	
	INPUT_1P_LEFT			= 1,				-- プレイヤー/左カツ
	INPUT_1P_RIGHT			= 2,				-- プレイヤー/右カツ
	INPUT_1P_DECIDE			= 3,				-- プレイヤー/ドン
	INPUT_2P_LEFT			= 4,				-- プレイヤー/左カツ
	INPUT_2P_RIGHT			= 5,				-- プレイヤー/右カツ
	INPUT_2P_DECIDE			= 6,				-- プレイヤー/ドン

	storyType				= 1,				-- 閲覧するストーリーのタイプ
	resultType              = kResultWaiting,	-- 最終的に選択した結果
	currentPhrase			= 2,				-- 現在の会話インデックス
	
	is_inputEnable 			= false,   			-- 入力受付可能フラグ
	is_TimeUp 				= false,   			-- タイムアウトになったか
	is_confirmationTimeUp 	= false,   			-- 確認画面時にタイムアウトになったか
	is_limitPage			= false,			-- 最後のページまで進んだか
	is_firstInput			= false,			-- カツ入力を1度でもしたか
	
	Init = function(this)

		-- ロードムービー等の準備
		this.AllState_.func_["Begin"] = function()
			-- 各種パーツ読み込み
			Debug.PrintString("[AIStoryAllMain] SequenceStart_Begin")
			this.storybg_:LoadMovieBg()

			this.AllState_:SetState("SetUp")
			Debug.PrintString("[AIStoryAllMain] SequenceEnd_Begin")
		end
		
		-- セットアップ
		this.AllState_.func_["SetUp"] = function()
			if (Lumen.IsLoadMovieFinish() == true) then
				
				this.mc_main  = Lumen.GetMovieClip("main",true)
				this.mc_kaiwa = Lumen.GetMovieClip("main/kaiwa",true)

				-- 背景
				this.storybg_:SetupBg()
				
				this:SelectPlayerStory()
				this:SetupGuide()
				
				this:SetVisibleTextPhrase(false)
				
				-- C側に準備完了通知
				Common.LuaPrepareFinish()
				
				this.mc_main:GotoAndPlay("in")
				
				this.AllState_:SetState("StartWait")
				Debug.PrintString("[AIStoryAllMain] SequenceEnd_Loading")

			end
		end
		
		-- 開始ウェイト
		this.AllState_.func_["StartWait"] = function()
		
			Debug.PrintString("[AIStoryAllMain] SequenceStart_StartWait")
			
			if(this.mc_main:IsPlay() == false) then
				
				this:SetVisibleTextPhrase(true)
				
				TSound:Play("se_common_v12a","action_callout_c")
				
				-- カウンター開始				
				this.start_cnt = 0
				this:SetInputEnable(true)
				
				this.AllState_:SetState("Main")
				
				Debug.PrintString("[AIStoryAllMain] SequenceEnd_StartWait")
			end
		end
		
		-- ストーリー画面
		this.AllState_.func_["Main"] = function()
			
			this:PlayerInputKatsu()
			
			-- 任意に段位を選択して確認画面に遷移するとき
			if (this:GetResultType() == this.kResultDecided) then				
				
				this.AllState_:SetState("End")
			end
		end
		
		-- プレイヤーの入力カット
		this.AllState_.func_["WaitInputCut"] = function()
			Debug.PrintString("[AIStoryAllMain] WaitInputCut")
			
			if (this:WaitInputCutCnt() == true) then 
				this.AllState_:SetState("Main")
			end
		end
		
		-- プレイヤーの面入力待ち
		this.AllState_.func_["WaitInputDon"] = function()
			Debug.PrintString("[AIStoryAllMain] WaitInputDon")
			this:ChangeGuide()
			
			if (this:PlayerInputDon() == true) then
				this.AllState_:SetState("End")
			end
		end

		-- 終了シーケンス
		this.AllState_.func_["End"] = function()
			Debug.PrintString("[AIStoryAllMain] End")
			
			-- C++ 側へ Lua 側終了の通知を送る
			Common.LuaFinish()
		end
	end,
	
-- ここまでAIStoryAllMainInit
	
	-- プレイヤーの入力可能開始までのカウント
	WaitCnt = function(this)
		this.start_cnt = this.start_cnt + 1
		
		if (this.start_cnt >= this.wait_start_cnt) then
			this.start_cnt = 0
			return true
		else return false
		end
	end,
	
	-- プレイヤーの入力待ちカウント
	WaitInputCnt = function(this, type)
		
		-- 通常なら1加算そうでないなら0.5加算(2回呼び出しパターン)
		if (type == true) then
			this.start_input_cnt = this.start_input_cnt + 1
		else
			this.start_input_cnt = this.start_input_cnt + 0.5
		end
		
		if (this.start_input_cnt >= this.wait_input_cnt) then
			this.start_input_cnt = 0
			return true
		else return false
		end
	end,
	
	-- プレイヤーの入力カットカウント
	WaitInputCutCnt = function(this)
		this.start_input_cut_cnt = this.start_input_cut_cnt + 1
		
		if (this.start_input_cut_cnt >= this.wait_input_cut_cnt) then
			this.start_input_cut_cnt = 0
			return true
		else return false
		end
	end,

	-- 入力待ちカウントをリセット
	ResetInputCnt = function(this)
		this.start_input_cnt = 0
	end,

	-- V11までのプレイヤーの進行状況でストーリーを選択する
	SelectPlayerStory = function(this)
		
		if (V11playerRank < 1) then
			this.storyType = 1
		elseif (V11playerRank >= 1 and V11playerRank < 10) then
			this.storyType = 2
		else
			this.storyType = 3
		end
		
		this.mc_main.kaiwa:GotoAndStop("node"..this.storyType)
		this.mc_main:GotoAndStop("kaiwa/node"..this.storyType ,"phrase1")
		this:UpdateSetText(this.currentPhrase)
	end,
	
	-- 操作ガイドのセットアップ
	SetupGuide = function(this)
		this.mc_main:GotoAndStop("kaiwa/guide" ,"next")
		this.mc_main:SetText("kaiwa/guide/guide_next/txt_guide_next","txt_guide_next","ai_story_guide_katsu")
	end,
	
	-- 操作ガイドのセットアップ
	ChangeGuide = function(this)
		this.mc_main:GotoAndStop("kaiwa/guide" ,"end")
		this.mc_main:SetText("kaiwa/guide/guide_end/txt_guide_end","txt_guide_end","ai_story_guide_don")
	end,

	-- ストーリーページの切り替え
	MoveNextPage = function(this)
		
		if (this.is_firstInput == false) then
			TSound:Play("bgm_aiintro_v12g", "maintheme_loop")
			this.is_firstInput = true
		end
		
		this.currentPhrase = this.currentPhrase + 1
		
		if (this.storyType == 1) then
			
			this.mc_main:GotoAndStop("kaiwa/node"..this.storyType ,this.tbl_StoryPhraseLabel_1[this.currentPhrase])
			this:MoveDonStory1(this.currentPhrase)
			this:MoveAIDonStory1(this.currentPhrase)
			this:MoveMakinaStory1(this.currentPhrase)
			this:UpdateSetText(this.currentPhrase)
			this:PlayVoiceStory1(this.currentPhrase)
			
			if (this.currentPhrase >= #this.tbl_StoryPhraseLabel_1) then
				this.currentPhrase = 1
				this:ResetInputCnt()
				this.AllState_:SetState("WaitInputDon")
				return				
			end
			
			this.AllState_:SetState("WaitInputCut")
			
		elseif (this.storyType == 2) then
			
			this.mc_main:GotoAndStop("kaiwa/node"..this.storyType ,this.tbl_StoryPhraseLabel_2[this.currentPhrase])
			this:MoveDonStory2(this.currentPhrase)
			this:MoveAIDonStory2(this.currentPhrase)
			this:MoveMakinaStory2(this.currentPhrase)
			this:UpdateSetText(this.currentPhrase)
			this:PlayVoiceStory2(this.currentPhrase)
			
			if (this.currentPhrase >= #this.tbl_StoryPhraseLabel_2) then
				this.currentPhrase = 1
				this:ResetInputCnt()
				this.AllState_:SetState("WaitInputDon")
				return				
			end
				
			this.AllState_:SetState("WaitInputCut")

		else	
			this.mc_main:GotoAndStop("kaiwa/node"..this.storyType ,this.tbl_StoryPhraseLabel_3[this.currentPhrase])
			this:MoveDonStory3(this.currentPhrase)
			this:MoveAIDonStory3(this.currentPhrase)
			this:MoveMakinaStory3(this.currentPhrase)
			this:UpdateSetText(this.currentPhrase)
			this:PlayVoiceStory3(this.currentPhrase)
			
			if (this.currentPhrase >= #this.tbl_StoryPhraseLabel_3) then
				this.currentPhrase = 1
				this:ResetInputCnt()
				this.AllState_:SetState("WaitInputDon")
				return				
			end
			
			this.AllState_:SetState("WaitInputCut")

		end
		
		this:ResetInputCnt()
	end,
	
	-- テキストの更新
	UpdateSetText = function(this, currentPhrase)
		this.mc_main:SetText("kaiwa/node"..this.storyType.."/txt_phrase","txt_phrase","ai_story_"..this.storyType.."_phrase_"..currentPhrase -1)
	end,
	
	-- フレーズの表示のON・OFF
	SetVisibleTextPhrase = function(this, flag_)
	
		this.mc_main.kaiwa.node1.txt_phrase:SetVisible(flag_)
		this.mc_main.kaiwa.node2.txt_phrase:SetVisible(flag_)
		this.mc_main.kaiwa.node3.txt_phrase:SetVisible(flag_)
		
	end,
	
	-- ストーリー1のどんちゃんの動き
	MoveDonStory1 = function(this, currentPhrase)
	
		if (currentPhrase == 5) then
			this.mc_main.kaiwa.node1.don_normal:Play()
		
		elseif (currentPhrase == 10 or currentPhrase == 14) then
			this.mc_main.kaiwa.node1.don_glad:Play()
		end
	end,

	-- ストーリー2のどんちゃんの動き
	MoveDonStory2 = function(this, currentPhrase)
	
		if (currentPhrase == 5) then
			this.mc_main.kaiwa.node2.don_normal:Play()
		
		elseif (currentPhrase == 8) then
			this.mc_main.kaiwa.node2.don_suprise:Play()
		
		elseif (currentPhrase == 10 or currentPhrase == 13) then
			this.mc_main.kaiwa.node2.don_glad:Play()
		end
	end,

	-- ストーリー3のどんちゃんの動き
	MoveDonStory3 = function(this, currentPhrase)
	
		if (currentPhrase == 5) then
			this.mc_main.kaiwa.node3.don_normal:Play()
		
		elseif (currentPhrase == 8) then
			this.mc_main.kaiwa.node3.don_suprise:Play()
		
		elseif (currentPhrase == 10 or currentPhrase == 14) then
			this.mc_main.kaiwa.node3.don_glad:Play()
		end
	end,

	-- ストーリー1のAIドンの動き
	MoveAIDonStory1 = function(this, currentPhrase)
	
		if (currentPhrase == 3) then
			this.mc_main.kaiwa.node1.aidon_normal:Play()
		
		elseif (currentPhrase == 15) then
			this.mc_main.kaiwa.node1.aidon_jump:Play()
		end
	end,

	-- ストーリー2のAIドンの動き
	MoveAIDonStory2 = function(this, currentPhrase)
	
		if (currentPhrase == 3 or currentPhrase == 7) then
			this.mc_main.kaiwa.node2.aidon_normal:Play()
		
		elseif (currentPhrase == 14) then
			this.mc_main.kaiwa.node2.aidon_jump:Play()
		end
	end,

	-- ストーリー3のAIドンの動き
	MoveAIDonStory3 = function(this, currentPhrase)
	
		if (currentPhrase == 3 or currentPhrase == 7) then
			this.mc_main.kaiwa.node3.aidon_normal:Play()
		
		elseif (currentPhrase == 15) then
			this.mc_main.kaiwa.node3.aidon_jump:Play()
		end
	end,
	
	-- ストーリー1のまきなの動き
	MoveMakinaStory1 = function(this, currentPhrase)
	
		if (currentPhrase == 4) then
			this.mc_main.kaiwa.node1.makina_normal:Play()
		elseif (currentPhrase == 6) then
			this.mc_main.kaiwa.node1.makina_worried:Play()
		elseif (currentPhrase == 7) then
			this.mc_main.kaiwa.node1.makina_wait:Play()
		elseif (currentPhrase == 11) then
			this.mc_main.kaiwa.node1.makina_smile_first:Play()
		elseif (currentPhrase == 16) then
			this.mc_main.kaiwa.node1.makina_smile_second:Play()
		end
	end,

	-- ストーリー2のまきなの動き
	MoveMakinaStory2 = function(this, currentPhrase)
	
		if (currentPhrase == 4) then
			this.mc_main.kaiwa.node2.makina_normal:Play()
		elseif (currentPhrase == 6) then
			this.mc_main.kaiwa.node2.makina_worried:Play()
		elseif (currentPhrase == 11 or currentPhrase == 13) then
			this.mc_main.kaiwa.node2.makina_wait:Play()
		elseif (currentPhrase == 9) then
			this.mc_main.kaiwa.node2.makina_smile_first:Play()
		elseif (currentPhrase == 12 or currentPhrase == 15) then
			this.mc_main.kaiwa.node2.makina_smile_second:Play()
		end
	end,

	-- ストーリー3のまきなの動き
	MoveMakinaStory3 = function(this, currentPhrase)
	
		if (currentPhrase == 4) then
			this.mc_main.kaiwa.node3.makina_normal:Play()
		elseif (currentPhrase == 6) then
			this.mc_main.kaiwa.node3.makina_worried:Play()
		elseif (currentPhrase == 11 or currentPhrase == 14) then
			this.mc_main.kaiwa.node2.makina_wait:Play()
		elseif (currentPhrase == 9 or currentPhrase == 13) then
			this.mc_main.kaiwa.node3.makina_smile_first:Play()
		elseif (currentPhrase == 16) then
			this.mc_main.kaiwa.node3.makina_smile_second:Play()
		end
	end,
	
	-- ストーリー1のSE再生
	PlayVoiceStory1 = function(this, currentPhrase)
	
		if (currentPhrase == 2) then
			-- なし
		elseif (currentPhrase == 3) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 4) then
			TSound:Play("se_common_v12a","action_callout_c")
			TSound:Play("voice_aistory_v12g","intro_01a")
		elseif (currentPhrase == 5) then
			TSound:Play("se_common_v12a","action_small_c")
		elseif (currentPhrase == 6) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 7) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 8) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 9) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 10) then
			TSound:Play("se_common_v12a","action_jump_c")
		elseif (currentPhrase == 11) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 12) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 13) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 14) then
			TSound:Play("se_common_v12a","action_jump_c")
		elseif (currentPhrase == 15) then
			TSound:Play("se_common_v12a","action_callout_c")
			TSound:Play("voice_aistory_v12g","intro_03")
		elseif (currentPhrase == 16) then
			TSound:Play("se_common_v12a","action_callout_c")
			TSound:Play("voice_aistory_v12g","intro_02")
		end

	end,
	
	-- ストーリー2のSE再生
	PlayVoiceStory2 = function(this, currentPhrase)
	
		if (currentPhrase == 2) then
			-- なし
		elseif (currentPhrase == 3) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 4) then
			TSound:Play("se_common_v12a","action_callout_c")
			TSound:Play("voice_aistory_v12g","intro_01b")
		elseif (currentPhrase == 5) then
			TSound:Play("se_common_v12a","action_small_c")
		elseif (currentPhrase == 6) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 7) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 8) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 9) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 10) then
			TSound:Play("se_common_v12a","action_jump_c")
		elseif (currentPhrase == 11) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 12) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 13) then
			TSound:Play("se_common_v12a","action_jump_c")
		elseif (currentPhrase == 14) then
			TSound:Play("se_common_v12a","action_callout_c")
			TSound:Play("voice_aistory_v12g","intro_03")
		elseif (currentPhrase == 15) then
			TSound:Play("se_common_v12a","action_callout_c")
			TSound:Play("voice_aistory_v12g","intro_02")
		end

	end,
	
	-- ストーリー3のSE再生
	PlayVoiceStory3 = function(this, currentPhrase)
	
		if (currentPhrase == 2) then
			-- なし
		elseif (currentPhrase == 3) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 4) then
			TSound:Play("se_common_v12a","action_callout_c")
			TSound:Play("voice_aistory_v12g","intro_01b")
		elseif (currentPhrase == 5) then
			TSound:Play("se_common_v12a","action_small_c")
		elseif (currentPhrase == 6) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 7) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 8) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 9) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 10) then
			TSound:Play("se_common_v12a","action_jump_c")
		elseif (currentPhrase == 11) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 12) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 13) then
			TSound:Play("se_common_v12a","action_callout_c")
		elseif (currentPhrase == 14) then
			TSound:Play("se_common_v12a","action_jump_c")
		elseif (currentPhrase == 15) then
			TSound:Play("se_common_v12a","action_callout_c")
			TSound:Play("voice_aistory_v12g","intro_03")
		elseif (currentPhrase == 16) then
			TSound:Play("se_common_v12a","action_callout_c")
			TSound:Play("voice_aistory_v12g","intro_02")
		end

	end,
	

	-- ユーザーデータを取得する
	GetUserData = function(this)
		Debug.PrintString("GetUserData")
		-- ユーザーデータ取得
		if (is_joinPlayer[1] == true) then
			play_data_ = PlayDataManager.GetEntryPlayData(0)
		else
			play_data_ = PlayDataManager.GetEntryPlayData(1)
		end
	end,
	
	-- プレイヤーの入力(カツのみ)
	PlayerInputKatsu = function(this)
	
		-- キー入力
		if (this:CheckInput() == this.INPUT_1P_RIGHT or this:CheckInput() == this.INPUT_2P_RIGHT or this:WaitInputCnt(false) == true) then
			Debug.PrintString("TriggeredRight")
			-- 右ふち
			this:PlaySeKatsu()				
			this:MoveNextPage()
			
		elseif (this:CheckInput() == this.INPUT_1P_LEFT or this:CheckInput() == this.INPUT_2P_LEFT or this:WaitInputCnt(false) == true) then
			Debug.PrintString("TriggeredLeft")
			-- 左ふち
			this:PlaySeKatsu()								
			this:MoveNextPage()
			
		end
	end,

	-- プレイヤーの入力(ドンのみ)
	PlayerInputDon = function(this)
	
		-- キー入力
		if ((this:CheckInput() == this.INPUT_1P_DECIDE or this:CheckInput() == this.INPUT_2P_DECIDE) or this:WaitInputCnt(true) == true) then
			-- 面
			this:PlaySeDon()
			return true
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
	
	-- 実行状態をセットする
	SetResultType = function(this, type)
		this.resultType = type
	end,

	-- 実行状態をゲットする
	GetResultType = function(this)
		return this.resultType
	end,
	
	-- 入力受付フラグをゲットする
	GetInputEnable = function(this)
		return this.is_inputEnable
	end,

	-- 入力受付フラグをゲットする
	SetInputEnable = function(this, type)
		this.is_inputEnable = type
	end,

	-- どんSEをエントリーによって鳴らす
	PlaySeDon = function(this)
		TSound:Play("se_common_v12a","don_c")
	end,
	
	-- カツSEをエントリーによって鳴らす
	PlaySeKatsu = function(this)
		TSound:Play("se_common_v12a","katsu_c")
	end,

	Update = function(this)
	
		-- ステート処理
		this.AllState_:Update()
		
	end,
-- ここまでUpdate

}
-- ここまでMain