-- AiResultPlayAllMain.lua
-- AIバトルリザルト画面:総合演奏結果
AiResultPlayAllMain = {}

-- 使うクラスを読み込む
require("common.Sound")
require("common.State")
require("common.NamePlate")
require("ai_result.AiResultScoreCounter")
require("ai_result.AiResultWinCounter")
require("ai_result.AiResultBg")
require("ai_result.AiResultReward")
require("ai_result.AiResultRewardToken")
require("ai_result.AiResultEventTokenBg")

-- このクラス
function AiResultPlayAllMain.New()
	return
	{
		-- 定数
		kWindowFadeInState = {
			-- ウィンドウの表示演出
			StartIn_		= 0,
			WindowIn_		= 1,
			CyberIn_		= 2,
			SongIn_			= 3,
			End_			= 99,
		},

		-- 変数
		state_				= State.New("AiResultPlayAllMain"),
		timer_				= 0,	-- 更新用タイマー

		scoreFront_			= {},	-- スコア[4]
		scoreBack_			= {},	-- スコア[4]
		BestScore_			= {},	-- ベストスコア[4]
		sectionScore_		= {},	-- 区間スコア[4][5]
		sectionBestScore_	= {},	-- 区間ベスト[4][5]

		fadeInState_		= 0,

		-- ムービークリップ
		mc_,						-- メインmc
		
		-- フラグ
		isEnd_				= false,
		isFadeInEnd_		= false,	-- フェードイン完了

		----------------------------------------
		-- state処理
		Init = function(this)
			-- 全体シーケンス
			this.state_.func_["Begin"] = function()
				-- 開始
				Debug.PrintString("[AiResultPlayAllMain] Begin")
				this.state_:SetState("Loading")
			end

			this.state_.func_["Loading"] = function()
				-- 読み込み待ち
				if (Lumen.IsLoadMovieFinish() == true) then
					Debug.PrintString("[AiResultPlayAllMain] Loading Finish")
					this.timer_ = 0
					this.state_:SetState("Wait")
					return
				end
			end

			this.state_.func_["Wait"] = function()
				if(this.timer_ > 100) then
					Debug.PrintString("[AiResultPlayAllMain] Wait Finish")
					this.timer_ = 0

					-- フェードイン開始
					this.state_:SetState("FadeIn")
					--this:StartWindowIn()
					this:StartFadeIn()

					this.DebugSetStart()	-- デバッグ用です
					return
				end
			end

			this.state_.func_["FadeIn"] = function()
				-- ウィンドウフェードイン
				if(this.isFadeInEnd_ == true) then
				--if(this.mc_:IsInCurrentLabelMc("", "wait") == true) then
					Debug.PrintString("[AiResultPlayAllMain] Wait Finish")
					this.timer_ = 0

					-- メイン開始
					this.state_:SetState("mainIn")

					this.DebugSetStart()	-- デバッグ用です
					return
				end

				this:UpdateFadeIn()
			end

			this.state_.func_["SongIn"] = function()
				-- 曲データ表示
			end

			this.state_.func_["mainIn"] = function()

				if(InputDon() == true)then
					Debug.PrintString("[AiResultPlayAllMain] mainIn Finish")
					this.state_:SetState("End")
				end
			end

			this.state_.func_["End"] = function()
				Debug.PrintString("[AiResultPlayAllMain] End")
				this.isEnd_ = true
			end
		end,

		-- 更新
		Update = function(this)
			-- ステート処理
			this.state_:Update()
			this.timer_ = this.timer_ + 1	--　タイマ更新
		end,

		-- 初期値の設定
		SetUp = function(this, mc)
			Debug.PrintString("[AiResultPlayAllMain] SetUp")
			-- mcの設定
			this.mc_ = mc
			this.mc_.main:GotoAndStop("init")


			-- 値の設定

			-- 仮の設定
			this.mc_.main.dummy_bg:SetVisible(false)
			this.mc_.main.chara_makina_mc:SetVisible(false)
			this:SetWindowSetiing()
			this:SetParam()
		end,

		-- LoadMovie
		LoadMovie = function(this)
			-- 読み込み
			Debug.PrintString("[AiResultPlayAllMain] LoadMovie")
			Lumen.LoadMovie("lumen/000_default/enso_ai/song_select/ai_song_select_bg","dummy_bg")		-- ごほうび

			--this.eventTokenBg_:LoadMovie()
		end,

		----------------------------------------
		-- その他

		SetWindowSetiing = function(this)
			-- プレイ曲数によるウィンドウ設定の変更
			local label = "song"..g_maxSongCount_

			this.mc_.main.window_cyber_set_mc:GotoAndStop(label)
			this.mc_.main.window_label_set_mc:GotoAndStop(label)
			this.mc_.main.window_base_set_mc:GotoAndStop(label)
			this.mc_.main.window_glow_mc.window_glow_set_mc:GotoAndStop(label)

			-- window_label_set_mc
			-- window_base_set_mc

		end,
		
		StartFadeIn = function(this)
			-- フェードイン開始

			this.mc_.main.dummy_bg:SetVisible(true)
			this.mc_.main.chara_makina_mc:SetVisible(true)
			this.fadeInState_ = this.kWindowFadeInState.StartIn_
		end,

		StartWindowIn = function(this)
			-- ウィンドウ表示
			this.mc_.main:GotoAndPlay("in")

			this.timer_ = 0
			this.isFadeInEnd_ = false
			this.fadeInState_ = this.kWindowFadeInState.WindowIn_
		end,

		StartSongIn = function(this)
			-- 曲情報の表示
			local label = "song"..g_maxSongCount_.."_in"
			this.mc_.main.song_set_mc:GotoAndPlay(label)
			this.fadeInState_ = this.kWindowFadeInState.SongIn_
		end,

		StartCyberIn = function(this)
			-- window_cyber_in_mc開始
			this.timer_ = 0
			this.mc_.main.window_cyber_set_mc.window_cyber_in_mc:GotoAndPlay("in")
			this.fadeInState_ = this.kWindowFadeInState.CyberIn_
		end,

		UpdateFadeIn = function(this)
			-- フェードイン更新
			if(this.fadeInState_ == this.kWindowFadeInState.StartIn_)then
				-- 開始
				if(this.timer_ >= 60)then
					this:StartWindowIn()
				end
			elseif(this.fadeInState_ == this.kWindowFadeInState.WindowIn_)then
				-- ウィンドウの表示
				if(this.mc_.main:IsInCurrentLabelMc("", "wait") == true)then
					this:StartCyberIn()
				end
			elseif(this.fadeInState_ == this.kWindowFadeInState.CyberIn_)then
				-- window_cyber_in_mc表示
				if(this.timer_ >= 40)then
					this:StartSongIn()
				end
			elseif(this.fadeInState_ == this.kWindowFadeInState.SongIn_)then
				-- 曲情報の表示
				if(this.mc_.main:IsInCurrentLabelMc("song_set_mc", "song"..g_maxSongCount_) == true)then
					this.fadeInState_ = this.kWindowFadeInState.End_
				end
			elseif(this.fadeInState_ == this.kWindowFadeInState.End_)then
				-- フェードイン演出完了
				this.isFadeInEnd_ = true
			end
		end,

		SetParam = function(this)
			-- 値の設定
			Debug.PrintString("[AiResultPlayAllMain] SetParam")

			-- メインテキスト設定
			this.mc_.main.window_label_set_mc.window_label_tx_mc:SetText("tx_label","ai_result_bestscore")	-- TODO:今回のプレイ結果テキストに差し替える

			for i=1,g_maxSongCount_ do
				-- 曲数分ループ
				Debug.PrintString("ループ目:"..i)
				
				local baseLabel = "song_base_mc_"..i
				local baseMc	=  this.mc_.main.song_set_mc:GetChildMc(baseLabel,true)
				baseMc:GotoAndStop("section_"..g_totalSectionNum_[i])
				Debug.PrintString("test")
				baseMc.song_bestscore_set_mc:GotoAndStop("on")									-- ベストスコア表示
				baseMc.song_bestscore_set_mc:SetText("tx_bestscore","ai_result_bestscore")		-- ベストスコアテキスト
				baseMc.song_bestscore_set_mc:SetVisible(true)									-- ベストスコアを表示しない場合、表示をしない

				baseMc.song_crown_mc:GotoAndStop(this:CrownToString(g_totalCrown_[i]))	-- 王冠 : none, silver, gold, rainbow

				baseMc.song_rank_mc:GotoAndStop("rank_"..g_totalscoreRank_[i])		-- スコアランク : none, rank_1~7

				baseMc.song_score_tx_mc:SetText("tx_songscore", "result_score")		-- スコアテキスト

				-- スコア設定
				this.scoreFront_[i] = AiResultScoreCounter.New("scoreFront_"..i)
				this.scoreFront_[i]:Init(baseMc.song_score_front_mc, 7, g_totalScoreNum_[i])
				this.scoreFront_[i]:SkipCounter()

				this.scoreBack_[i] = AiResultScoreCounter.New("scoreBack_"..i)
				this.scoreBack_[i]:Init(baseMc.song_score_back_mc, 7, g_totalScoreNum_[i])
				this.scoreBack_[i]:SkipCounter()

				this.BestScore_[i] = AiResultScoreCounter.New("bestScore_"..i)
				this.BestScore_[i]:Init(baseMc.song_bestscore_set_mc.best_score_num, 7, g_totalBestScoreNum_[i])
				this.BestScore_[i]:SkipCounter()

				this.sectionScore_[i]		= {}	-- 区間スコア[4][5]
				this.sectionBestScore_[i]	= {}	-- 区間ベスト[4][5]

				--曲名
				baseMc.song_base_name_tx_mc:SetText("tx_songname", g_totalSongName_[i])
				Debug.PrintString("区間")
				for j=1,g_totalSectionNum_[i] do
					-- 区間数分ループ
					Debug.PrintString("区間ループ目:"..j)
					local sectionLabel = "section_mc_"..j
					local sectionMc = baseMc:GetChildMc(sectionLabel,true)
					sectionMc.section_bestscore_set_mc:GotoAndStop("on")	-- ベストスコア表示 : off/on

					sectionMc.section_label_tx_mc:SetText("tx_section","ai_song_select_section_"..j)	-- 区間数テキスト
					sectionMc.section_score_tx_mc:SetText("tx_sectionscore","result_score")				-- スコアテキスト

					sectionMc.section_crown_mc:GotoAndStop(this:CrownToString(g_totalSectionCrown_[i][j]))	-- 王冠 : none, silver, gold, rainbow

					-- スコアの設定
					this.sectionScore_[i][j] = AiResultScoreCounter.New("sectionScore_"..j)
					this.sectionScore_[i][j]:Init(sectionMc.section_score_mc, 8, g_totalSectionTotalScore_[i][j])
					this.sectionScore_[i][j]:SkipCounter()

					this.sectionBestScore_[i][j] = AiResultScoreCounter.New("sectionBestScore_"..j)
					this.sectionBestScore_[i][j]:Init(sectionMc.section_bestscore_set_mc.best_score_num, 7, g_totalBestSectionTotalScore_[i][j])
					this.sectionBestScore_[i][j]:SkipCounter()
				end
			end

		end,

		CrownToString = function(this, num)
			Debug.PrintString("[AiResultPlayAllMain] CrownToString")
			if(num == 0)then
				return "none"
			elseif(num == 1)then
				return "silver"
			elseif(num == 2)then
				return "gold"
			elseif(num == 3)then
				return "rainbow"
			end
		end,

		DebugSetStart = function(this)
			Debug.PrintString("[AiResultPlayAllMain] DebugSetStart")
			-- this.mcReward_.main:GotoAndStop("use_right")
			-- this.mcReward_.main:GotoAndStop("use_left")
			-- this.mcReward_.main.reward_base_R.reward_panel:GotoAndPlay("start")
			-- this.mcReward_.main.token_base_R:GotoAndPlay("start")
			-- this.mcToken_.main:GotoAndStop("use_left")
			-- this.mcToken_.main.token_base_L:GotoAndPlay("start")
		end,

	}
end
