-- AiPlayAllWindow.lua
-- AIバトルリザルト画面:総合演奏結果
AiPlayAllWindow = {}

-- 使うクラスを読み込む
require("common.Sound")
require("common.State")
require("common.NamePlate")
require("ai_result.AiResultScoreCounter")
require("ai_result.AiResultWinCounter")

-- このクラス
function AiPlayAllWindow.New()
	return
	{
		-- 定数
		kWindowFadeInState = {
			-- ウィンドウの表示演出
			StartIn_		= 0,
			WindowIn_		= 1,
			CyberIn_		= 2,
			SongIn_			= 3,
			MakinaSmileIn_	= 4,
			End_			= 99,
		},

		kWaitFadeInEndTime_		= 60,		-- 表示しきってから入力出来るまでの時間
		kWaitEndTime_			= 7200,		-- 入力出来るようになってから、強制終了までの時間

		-- 変数
		state_				= State.New("AiPlayAllWindow"),
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
		isFadeInEndWait_	= false,	-- フェードイン完了後の待機中
		isEndWait_			= false,	-- 入力できるようになってから強制終了までの待機

		-- ベスト表示フラグ
		isBestTotal_		= false,	-- 全体通してベスト更新箇所の有無
		isBestScore_		= {},		-- スコア[4]
		isBestCrown_		= {},		-- 王冠[4]
		isBestScoreRank_	= {},		-- スコアランク[4]
		isSectionBestScore_	= {},		-- 区間スコア[4][5]
		isSectionBestCrown_	= {},		-- 区間王冠[4][5]

		----------------------------------------
		-- state処理
		Init = function(this)
			-- 全体シーケンス
			this.state_.func_["Begin"] = function()
				-- 開始
				Debug.PrintString("[AiPlayAllWindow] Begin")
				this.state_:SetState("Loading")
			end

			this.state_.func_["Loading"] = function()
				-- 読み込み待ち
				if (Lumen.IsLoadMovieFinish() == true) then
					Debug.PrintString("[AiPlayAllWindow] Loading Finish")
					this.timer_ = 0
					this.state_:SetState("Wait")
					return
				end
			end

			this.state_.func_["Wait"] = function()
				if(this.timer_ > 100) then
					Debug.PrintString("[AiPlayAllWindow] Wait Finish")
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
					Debug.PrintString("[AiPlayAllWindow] Wait Finish")
					this.timer_ = 0
					this.isFadeInEndWait_ = true

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

				-- フェードイン完了後の待機時間
				if(this.isFadeInEndWait_ == true)then
					if(this.timer_ >= this.kWaitFadeInEndTime_)then
						this.isFadeInEndWait_ = false
					end
				end

				if(InputDon() == true or this.timer_ >= this.kWaitEndTime_)then
					Debug.PrintString("[AiPlayAllWindow] mainIn Finish")
					this.state_:SetState("End")
				end
			end

			this.state_.func_["End"] = function()
				Debug.PrintString("[AiPlayAllWindow] End")
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
			Debug.PrintString("[AiPlayAllWindow] SetUp")
			-- mcの設定
			this.mc_ = mc
			this.mc_.main:GotoAndStop("init")

			-- 値の設定

			-- 仮の設定
			this.mc_.main.dummy_bg:SetVisible(true)
			this.mc_.main.chara_makina_mc:SetVisible(true)
			this:SetWindowSetiing()
			this:SetParam()
		end,

		-- LoadMovie
		LoadMovie = function(this)
			-- 読み込み
			Debug.PrintString("[AiPlayAllWindow] LoadMovie")
			Lumen.LoadMovie("lumen/000_default/enso_ai/song_select/ai_song_select_bg","dummy_bg")		-- ごほうび

			--this.eventTokenBg_:LoadMovie()
		end,

		----------------------------------------
		-- その他

		SetWindowSetiing = function(this)
			-- プレイ曲数によるウィンドウ設定の変更
			Debug.PrintString("[AiPlayAllWindow] SetWindowSetiing")
			local label = "song"..g_maxSongCount_

			this.mc_.main.window_cyber_set_mc:GotoAndStop(label)
			this.mc_.main.window_label_set_mc:GotoAndStop(label)
			this.mc_.main.window_base_set_mc:GotoAndStop(label)
			this.mc_.main.window_glow_mc.window_glow_set_mc:GotoAndStop(label)
		end,
		
		StartFadeIn = function(this)
			-- フェードイン開始
			Debug.PrintString("[AiPlayAllWindow] StartFadeIn")
			--this.mc_.main.dummy_bg:SetVisible(true)
			--this.mc_.main.chara_makina_mc:SetVisible(true)
			this.fadeInState_ = this.kWindowFadeInState.StartIn_
		end,

		StartWindowIn = function(this)
			-- ウィンドウ表示
			Debug.PrintString("[AiPlayAllWindow] StartWindowIn")
			this.mc_.main:GotoAndPlay("in")
			TSound:Play("se_airesult_v12g","window_total")		-- SE:全曲まとめ成績ウィンドウ表示

			this.timer_ = 0
			this.isFadeInEnd_ = false
			this.fadeInState_ = this.kWindowFadeInState.WindowIn_
		end,

		StartSongIn = function(this)
			-- 曲情報の表示
			Debug.PrintString("[AiPlayAllWindow] StartSongIn")
			local label = "song"..g_maxSongCount_.."_in"
			this.mc_.main.song_set_mc:GotoAndPlay(label)
			this.fadeInState_ = this.kWindowFadeInState.SongIn_
		end,

		StartCyberIn = function(this)
			-- window_cyber_in_mc開始
			Debug.PrintString("[AiPlayAllWindow] StartCyberIn")
			this.timer_ = 0
			this.mc_.main.window_cyber_set_mc.window_cyber_in_mc:GotoAndPlay("in")
			this.fadeInState_ = this.kWindowFadeInState.CyberIn_
		end,

		UpdateFadeIn = function(this)
			-- フェードイン更新
			if(this.fadeInState_ == this.kWindowFadeInState.StartIn_)then
				-- 開始
				if(this.timer_ >= 120)then
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
					this.timer_ = 0
					this.fadeInState_ = this.kWindowFadeInState.MakinaSmileIn_
				end
			elseif(this.fadeInState_ == this.kWindowFadeInState.MakinaSmileIn_)then
				-- まきな、笑う
				if(this.timer_ >= 60)then
					this.timer_ = 0
					this.mc_.main.chara_makina_mc:GotoAndPlay("smile")
					this.fadeInState_ = this.kWindowFadeInState.End_
					if(this.isBestTotal_ == true)then
						-- ボイス「ベスト更新！」
						TSound:Play("voice_result_v12a","bestscore_c")
					end
				end
			elseif(this.fadeInState_ == this.kWindowFadeInState.End_)then
				-- フェードイン演出完了
				this.isFadeInEnd_ = true
			end
		end,

		SetParam = function(this)
			-- 値の設定
			Debug.PrintString("[AiPlayAllWindow] SetParam")
			this.isBestTotal_ = false

			-- メインテキスト設定
			this.mc_.main.window_label_set_mc.window_label_tx_mc:SetText("tx_label","ai_play_all_text")	-- TODO:今回のプレイ結果テキストに差し替える

			-- ベストスコアのフラグ設定
			this:SetBestScoreFlag()
			this:SetBestSectionScoreFlag()

			for i=1,g_maxSongCount_ do
				-- 曲数分ループ
				Debug.PrintString("ループ目:"..i)
				
				local baseLabel = "song_base_mc_"..i
				local baseMc	=  this.mc_.main.song_set_mc:GetChildMc(baseLabel,true)
				baseMc:GotoAndStop("section_"..g_totalSectionNum_[i])

				-- ベストスコア表示
				if(this.isBestScore_[i] == true)then
					this.isBestTotal_ = true
					baseMc.song_bestscore_set_mc:GotoAndStop("on")									-- ベストスコア表示
					baseMc.song_bestscore_set_mc:SetText("tx_bestscore","ai_result_bestscore")		-- ベストスコアテキスト
					baseMc.song_bestscore_set_mc:SetVisible(true)									-- ベストスコアを表示しない場合、表示をしない
				else
					baseMc.song_bestscore_set_mc:GotoAndStop("off")									-- ベストスコア表示
					baseMc.song_bestscore_set_mc:SetVisible(false)									-- ベストスコアを表示しない場合、表示をしない
				end

				this:SetCrown(baseMc.song_crown_mc, g_totalCrown_[i], this.isBestCrown_[i])					-- 王冠 : none, silver, gold, rainbow
				this:SetScoreRank(baseMc.song_rank_mc, g_totalscoreRank_[i], this.isBestScoreRank_[i])		-- スコアランク : none, rank_1~7

				baseMc.song_score_tx_mc:SetText("tx_songscore", "result_score")		-- スコアテキスト

				-- スコア設定
				this.scoreFront_[i] = AiResultScoreCounter.New("scoreFront_"..i)
				this.scoreFront_[i]:Init(baseMc.song_score_front_mc, 7, g_totalScoreNum_[i])
				this.scoreFront_[i]:SkipCounter()

				this.scoreBack_[i] = AiResultScoreCounter.New("scoreBack_"..i)
				this.scoreBack_[i]:Init(baseMc.song_score_back_mc, 7, g_totalScoreNum_[i])
				this.scoreBack_[i]:SkipCounter()

				this.BestScore_[i] = AiResultScoreCounter.New("bestScore_"..i)
				if(this.isBestScore_[i] == true)then
					this.BestScore_[i]:Init(baseMc.song_bestscore_set_mc.best_score_num, 7, g_totalScoreNum_[i] - g_totalBestScoreNum_[i])
				else
					this.BestScore_[i]:Init(baseMc.song_bestscore_set_mc.best_score_num, 7, 0)
				end
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

					--if(g_isBestScore_ == true)then
					if(this.isSectionBestScore_[i][j] == true)then
						this.isBestTotal_ = true
						sectionMc.section_bestscore_set_mc:GotoAndStop("on")	-- ベストスコア表示 : off/on
						sectionMc.section_bestscore_set_mc:SetVisible(true)
					else
						sectionMc.section_bestscore_set_mc:GotoAndStop("off")	-- ベストスコア表示 : off/on
						sectionMc.section_bestscore_set_mc:SetVisible(false)
					end

					sectionMc.section_label_tx_mc:SetText("tx_section","ai_song_select_section_"..j)	-- 区間数テキスト
					sectionMc.section_score_tx_mc:SetText("tx_sectionscore","result_score")				-- スコアテキスト

					this:SetSectionCrown(sectionMc.section_crown_mc, g_totalSectionCrown_[i][j], this.isSectionBestCrown_[i][j])		-- 王冠 : none, silver, gold, rainbow

					-- スコアの設定
					this.sectionScore_[i][j] = AiResultScoreCounter.New("sectionScore_"..j)
					this.sectionScore_[i][j]:Init(sectionMc.section_score_mc, 7, g_totalSectionTotalScore_[i][j])
					this.sectionScore_[i][j]:SkipCounter()

					this.sectionBestScore_[i][j] = AiResultScoreCounter.New("sectionBestScore_"..j)
					if(this.isSectionBestScore_[i][j] == true)then
						local updateScore = g_totalSectionTotalScore_[i][j] - g_totalBestSectionTotalScore_[i][j]
						this.sectionBestScore_[i][j]:Init(sectionMc.section_bestscore_set_mc.best_score_num, 7, updateScore)
					else
						this.sectionBestScore_[i][j]:Init(sectionMc.section_bestscore_set_mc.best_score_num, 7, 0)
					end
					this.sectionBestScore_[i][j]:SkipCounter()
				end
			end

		end,

		SetScoreRank = function(this, mc, rank, isBest)
			-- スコアランクの設定
			Debug.PrintString("[AiPlayAllWindow] SetScoreRank")
			if(rank == 0)then
				-- スコアランク無し
				mc:GotoAndStop("none")
			else
				-- スコアランク設定
				mc:GotoAndStop("rank_"..rank)

				local label = "song_rank_loop_"..rank.."_mc"
				local effMc = mc:GetChildMc(label,true)
				if(isBest == true)then
					effMc.eff_mc:GotoAndPlay("on")
				else
					effMc.eff_mc:GotoAndStop("off")
				end
			end
		end,

		SetCrown = function(this, mc, crown, isBest)
			-- 王冠設定
			Debug.PrintString("[AiPlayAllWindow] SetCrown")
			local crownLabel = this:CrownToString(crown)
			
			mc:GotoAndStop(crownLabel)
			if(crown ~= 0)then
				local label = "song_crown_loop_"..crownLabel.."_mc"
				local effMc = mc:GetChildMc(label,true)
				if(isBest == true)then
					effMc.eff_mc:GotoAndPlay("on")
				else
					effMc.eff_mc:GotoAndStop("off")
				end
			end
		end,

		SetSectionCrown = function(this, mc, crown, isBest)
			-- 区間王冠設定
			Debug.PrintString("[AiPlayAllWindow] SetCrown")
			local crownLabel = this:CrownToString(crown)
			
			mc:GotoAndStop(crownLabel)
			if(crown ~= 0)then
				local label = "section_crown_loop_"..crownLabel.."_mc"
				local effMc = mc:GetChildMc(label,true)
				if(isBest == true)then
					effMc.eff_mc:GotoAndPlay("on")
				else
					effMc.eff_mc:GotoAndStop("off")
				end
			end
		end,

		CrownToString = function(this, num)
			Debug.PrintString("[AiPlayAllWindow] CrownToString")
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

		SetBestScoreFlag = function(this)
			-- ベストスコアの表示フラグを設定
			Debug.PrintString("[AiPlayAllWindow] SetBestScoreFlag")
			-- プレイ開始時のベストスコアと比較
			for i=1,g_maxSongCount_ do
				-- 曲数分ループ

				-- スコア
				if(g_totalScoreNum_[i] > g_totalBestScoreNum_[i] and g_totalBestScoreNum_[i] ~= 0 and g_isAllOnpuEnd_[i] == true)then
					this.isBestScore_[i] = true
				else
					this.isBestScore_[i] = false
				end

				-- 王冠
				if(g_totalCrown_[i] > g_totalBestCrown_[i] and g_totalBestCrown_[i] ~= 0 and g_isAllOnpuEnd_[i] == true)then
					this.isBestCrown_[i] = true
				else
					this.isBestCrown_[i] = false
				end

				-- スコアランク
				if(g_totalscoreRank_[i] > g_totalBestScoreRank_[i] and g_totalBestScoreRank_[i] ~= 0 and g_isAllOnpuEnd_[i] == true)then
					this.isBestScoreRank_[i] = true
				else
					this.isBestScoreRank_[i] = false
				end
			end

			-- 同じ曲、同じ難易度の場合のベストスコアを比較
			for i=1,g_maxSongCount_ do
				-- 曲数分ループ
				for j=1,g_maxSongCount_ do
					-- 曲数分ループ
					if(i ~= j and g_totalSongName_[i] == g_totalSongName_[j] and g_totalDifficulty_[i] == g_totalDifficulty_[j])then
						-- 曲と難易度が同じな場合、比較する

						-- スコア
						if(g_totalScoreNum_[i] < g_totalScoreNum_[j])then
							this.isBestScore_[i] = false
						end

						if(g_totalScoreNum_[i] == g_totalScoreNum_[j] and this.isBestScore_[i] == true)then
							this.isBestScore_[j]	= true
							g_totalBestScoreNum_[j]	= g_totalBestScoreNum_[i]
						end

						-- 王冠
						if(g_totalCrown_[i] < g_totalCrown_[j])then
							this.isBestCrown_[i] = false
						end

						if(g_totalCrown_[i] == g_totalCrown_[j] and this.isBestCrown_[i] == true)then
							this.isBestCrown_[j]	= true
							g_totalBestCrown_[j]	= g_totalBestCrown_[i]
						end

						-- スコアランク
						if(g_totalscoreRank_[i] < g_totalscoreRank_[j])then
							this.isBestScoreRank_[i] = false
						end

						if(g_totalscoreRank_[i] == g_totalscoreRank_[j] and this.isBestScoreRank_[i] == true)then
							this.isBestScoreRank_[j]	= true
							g_totalBestScoreRank_[j]	= g_totalBestScoreRank_[i]
						end

						for j=1,g_totalSectionNum_[i] do
							-- 区間数分ループ
							-- 区間スコア
							-- 区間王冠
						end
					end
				end
			end
		end,

		SetBestSectionScoreFlag = function(this)
			-- 区間ベストスコアの表示フラグを設定
			Debug.PrintString("[AiPlayAllWindow] SetBestSectionScoreFlag")
			-- プレイ開始時のベストスコアと比較
			for i=1,g_maxSongCount_ do
				-- 曲数分ループ

				this.isSectionBestScore_[i] = {}
				this.isSectionBestCrown_[i] = {}
				for j=1,g_totalSectionNum_[i] do
					-- 区間数分ループ

					-- 区間スコア
					if(g_totalSectionTotalScore_[i][j] > g_totalBestSectionTotalScore_[i][j] and g_totalBestSectionTotalScore_[i][j] ~= 0 and g_isAllOnpuEnd_[i] == true)then
						this.isSectionBestScore_[i][j] = true
					else
						this.isSectionBestScore_[i][j] = false
					end
					-- 区間王冠
					if(g_totalSectionCrown_[i][j] > g_totalBestSectionCrown_[i][j] and g_totalBestSectionCrown_[i][j] ~= 0 and g_isAllOnpuEnd_[i] == true)then
						this.isSectionBestCrown_[i][j] = true
					else
						this.isSectionBestCrown_[i][j] = false
					end
				end
			end

			-- 同じ曲、同じ難易度の場合のベストスコアを比較
			for i=1,g_maxSongCount_ do
				-- 曲数分ループ
				for j=1,g_maxSongCount_ do
					-- 曲数分ループ
					if(i ~= j and g_totalSongName_[i] == g_totalSongName_[j] and g_totalDifficulty_[i] == g_totalDifficulty_[j])then
						-- 曲と難易度が同じな場合、比較する
						for k=1,g_totalSectionNum_[i] do
							-- 区間数分ループ

							-- 区間スコア
							if(g_totalSectionTotalScore_[i][k] < g_totalSectionTotalScore_[j][k])then
								this.isSectionBestScore_[i][k] = false
							end
							
							-- 区間王冠
							if(g_totalSectionCrown_[i][k] < g_totalSectionCrown_[j][k])then
								this.isSectionBestCrown_[i][k] = false
							end
						end
					end
				end
			end
		end,

		DebugSetStart = function(this)
			Debug.PrintString("[AiPlayAllWindow] DebugSetStart")
			-- this.mcReward_.main:GotoAndStop("use_right")
			-- this.mcReward_.main:GotoAndStop("use_left")
			-- this.mcReward_.main.reward_base_R.reward_panel:GotoAndPlay("start")
			-- this.mcReward_.main.token_base_R:GotoAndPlay("start")
			-- this.mcToken_.main:GotoAndStop("use_left")
			-- this.mcToken_.main.token_base_L:GotoAndPlay("start")
		end,

	}
end
