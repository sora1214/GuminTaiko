--	スコアベース
--	2019/09/05
--	y-hara (Yasunori_Hara@al.bandainamco.jp)
--	各種スコアとか魂ゲージとかが載ったウィンドウ

require("common.Sound")
require("result.ScoreCounter")

ScoreBase = {}
function ScoreBase.New(name)
	return
	{
		name_ = name,
		state_ = State.New(name),
		isEffectSkip_ = false,			-- 演出スキップするか否か
		isStartDisplayScore_ = false,	-- スコアを含む各種数値結果を表示し始めたか否か
		isEndDisplayScore_ = false,		-- スコアを含む各種数値結果を表示し終えたか否か
		isDisplayScoreRank_ = false,	-- スコアランクを表示したか否か
		isDisplayCrown_ = false,		-- 王冠を表示したか否か
		isNewRecord_ = false,			-- ハイスコア記録を更新したか否か
		timer_ = 0,						-- タイマ
		scoreIndex_ = 1,				-- 各種スコア表示用
		
		player_,			-- 1pか2pか（右側の太鼓で１人プレイの場合は1pになります。ご注意を）
		isUseRight_ = false,-- このウィンドウが右側に表示されるか否か
		mc_,				-- このMC
		numMc_ = {},		-- 各種数値系のMC
		totalScoreMc_,		--　スコアMC
		totalScoreBackMc_,-- スコア縁取りMC
		goodNumMc_,			-- "良"の値MC
		okNumMc_,			-- "可"の値MC
		badNumMc_,			-- "不可"の値MC
		maxcomboNumMc_,		-- "最大コンボ数"の値MC
		dramrollNumMc_,		-- "最大連打数"の値MC
		crownMc_,			-- 王冠MC
		scoreRankMc_,		-- スコアランクMC
		scoreRankKiwamiMc_,	-- スコアランク"極"MC
		difficultyMc_,		-- 難易度アイコンMC
		bestScoreMc_,		-- 自己ベスト更新MC

		
		-- 各種スコア系のScoreCounterをNewする
		totalScore_ = ScoreCounter.New("totalScore"),
		totalScoreBack_ = ScoreCounter.New("totalScoreBack"),
		goodNum_ = ScoreCounter.New("goodNum"),
		okNum_ = ScoreCounter.New("okNum"),
		badNum_ = ScoreCounter.New("badNum"),
		maxcomboNum_ = ScoreCounter.New("maxcomboNum"),
		dramrollNum_ = ScoreCounter.New("dramrollNum"),
		updateScoreNum_ = ScoreCounter.New("updateScore"),

	
		Init = function(this, mc)
			Debug.PrintString("!!!ScoreBase Initialize!!!@"..this.name_)
			
			this.state_.func_["Begin"] = function()
				Lumen.Play()
									
				this.mc_ = mc
				this.totalScoreMc_ 		= mc:GetChildMc("total_score_mc",true)
				this.totalScoreBackMc_ 	= mc:GetChildMc("total_score_back_mc",true)
				this.goodNumMc_ 		= mc:GetChildMc("good_num_mc",true)			
				this.okNumMc_ 			= mc:GetChildMc("ok_num_mc",true)
				this.badNumMc_ 			= mc:GetChildMc("bad_num_mc",true)
				this.maxcomboNumMc_ 	= mc:GetChildMc("max_combo_num_mc",true)			
				this.dramrollNumMc_ 	= mc:GetChildMc("dramroll_num_mc",true)		
				this.crownMc_ 			= mc:GetChildMc("crown_mc",true)		-- 王冠
				this.crownMc_:SetVisible(false)
				this.scoreRankMc_ 		= mc:GetChildMc("score_rank_mc",true)	-- スコアランク
				this.scoreRankMc_:SetVisible(false)
				this.scoreRankKiwamiMc_ = mc:GetChildMc("score_rank_kiwami_mc",true)	-- スコアランク
				this.scoreRankKiwamiMc_:SetVisible(false)
				this.difficultyMc_ 		= mc:GetChildMc("difficulty_mc",true)	-- 難易度アイコン
				this.difficultyMc_:SetVisible(false)
				this.bestScoreMc_		= mc:GetChildMc("best_score_mc",true)	-- 自己ベスト更新
				this.bestScoreMc_:SetVisible(false)
	
				this.state_:SetState("Loading")	
	
			end
			
			
			this.state_.func_["Loading"] = function()
				if(Lumen.IsLoadMovieFinish() == true) then
					this.mc_:SetText("score_text","result_score")				
					-- １p2pどちらかを判断。２人プレイ時はname_から判別し、それ以外の場合は問答無用で１p
					if(g_entryType == 2) then	-- ２人プレイの場合
						if(this.name_ == "scoreBase1p")	then
							this.player_ = 1
							this.mc_:GotoAndStop("1P") -- 背景を赤に色替え
							this.isUseRight_ = false
						else
							this.player_ = 2
							this.mc_:GotoAndStop("2P") -- 背景を青に色替え
							this.isUseRight_ = true
						end
					else
						this.player_ = 1
						if(g_entryType == 0) then
							this.mc_:GotoAndStop("1P") -- 背景を赤に色替え
							this.isUseRight_ = false
						else
							this.mc_:GotoAndStop("2P") -- 背景を青に色替え
							this.isUseRight_ = true
						end
					end

					-- ハイスコア演出が必要か否か判断
					if(g_hiscore[this.player_] ~= 0 and g_totalScore[this.player_] > g_hiscore[this.player_]) then
						this.isNewRecord_ = true
						this.bestScoreMc_:SetVisible(true)
						updateScore = g_totalScore[this.player_] - g_hiscore[this.player_]
						hiscoreNumMc = this.bestScoreMc_:GetChildMc("best_score_num",true)	
						this.updateScoreNum_:Init(hiscoreNumMc, 7, updateScore)
					end

					this.totalScore_:Init(this.totalScoreMc_, 7, g_totalScore[this.player_])
					this.totalScoreBack_:Init(this.totalScoreBackMc_, 7, g_totalScore[this.player_])
					this.goodNum_:Init(this.goodNumMc_, 4, g_goodNum[this.player_])
					this.okNum_:Init(this.okNumMc_, 4, g_okNum[this.player_])
					this.badNum_:Init(this.badNumMc_, 4, g_badNum[this.player_])
					this.dramrollNum_:Init(this.dramrollNumMc_, 4, g_dramrollNum[this.player_])
					this.maxcomboNum_:Init(this.maxcomboNumMc_, 4, g_maxcomboNum[this.player_])
					
					-- 各種数値系のMCを格納
					this.numMc_[1] = this.goodNum_
					this.numMc_[2] = this.okNum_
					this.numMc_[3] = this.badNum_
					this.numMc_[4] = this.dramrollNum_
					this.numMc_[5] = this.maxcomboNum_
					this.numMc_[6] = this.totalScore_
					this.numMc_[7] = this.totalScoreBack_
					
					this.state_:SetState("Start")
				end
			end
			
			
			this.state_.func_["Start"] = function()
				this:StartDifficultyDisplay()
				this.state_:SetState("End")
			end
			
			
			this.state_.func_["End"] = function()	
			end
			
		end,		
		-- ここまでInit
					
			
		--	毎フレーム実行
		Update = function(this, isEffectSkip)
			this.isEffectSkip_ = isEffectSkip
		
			this.state_:Update()

			if(this.isStartDisplayScore_ == true and this.isEndDisplayScore_ == false) then			
				this.totalScore_:Update()
				this.totalScoreBack_:Update()
				this.goodNum_:Update()
				this.okNum_:Update()
				this.badNum_:Update()
				this.maxcomboNum_:Update()
				this.dramrollNum_:Update()
				
				this:UpdateScoreDisplay()
			end
		end,
		-- ここまでUpdate


	
		-- 各種スコアの表示指示を出す
		StartScoreDisplay = function(this)
			this.isStartDisplayScore_ = true
		end,
		-- ここまでStartOutputScore
	
		
		
		-- 各種スコアの表示を更新する
		UpdateScoreDisplay = function(this)
			-- スキップONなら7種類すべて一挙に表示
			if(this.isEffectSkip_ == true) then
				for idx = 1, 7 do
					this.numMc_[idx]:SkipCounter()
				end
				if(this.player_ == 1) then
					TSound:Play("se_common_v12a","don_big")
				end
				this:DisplayHiscoreEffect()
				this.isEndDisplayScore_ = true
			-- スキップOFFなら5種類（良・可・不可・コンボ・連打）を等間隔でずらして、最後１種類（スコア）はちょっとためてから表示
			else
				this.timer_ = this.timer_ + 1			
				if(this.timer_ > 50 and this.scoreIndex_ < 6) then
					this.timer_ = 0
					this.numMc_[this.scoreIndex_]:SkipCounter()
					this.scoreIndex_ = this.scoreIndex_ + 1
					if(this.player_ == 1) then
						TSound:Play("se_common_v12a","count_stop_c")
					end	
				elseif(this.timer_ > 100 and this.scoreIndex_ == 6) then
					this.numMc_[6]:SkipCounter()
					this.numMc_[7]:SkipCounter()
					if(this.player_ == 1) then
						TSound:Play("se_common_v12a","don_big")
					end
					this:DisplayHiscoreEffect()
					this.isEndDisplayScore_ = true
				end
			end
		end,
		-- ここまでUpdateScoreDisplay
		
		
		
		-- ハイスコア更新演出の再生
		DisplayHiscoreEffect = function(this)
			if(this.isNewRecord_ == true)then
				this.bestScoreMc_.best_score_text:SetText("text","result_bestscore")	-- 「ベストスコア更新！」テキスト
				this.updateScoreNum_:SkipCounter()				
				this.bestScoreMc_:GotoAndPlay("start")
				-- ボイス「ベスト更新！」
				if(this.isUseRight_ == false) then
					TSound:Play("voice_result_v12a","bestscore_l")
				else
					TSound:Play("voice_result_v12a","bestscore_r")
				end

			end
		end,
		-- ここまでDisplayHiscoreEffect
		
		
		
		-- スコアランクの表示指示を出す
		StartScoreRankDisplay = function(this)
			if(g_scoreRank[this.player_] == 0) then
				return
			end
		
			if(g_scoreRank[this.player_] == 7) then	-- スコアランクが"極"なら実行
				this.scoreRankKiwamiMc_:SetVisible(true)
				-- スキップONなら演出を飛ばして表示だけ行う
				if(this.isEffectSkip_ == true) then
					this.scoreRankKiwamiMc_:GotoAndStop("end")
					this.isDisplayScoreRank_ = true	
				-- スキップOFFかつスコアランク未表示なら、演出つきで表示する
				elseif(this.isDisplayScoreRank_ == false) then
					this.scoreRankKiwamiMc_:GotoAndPlay("start")
					this.isDisplayScoreRank_ = true
					this:PlayScoreRankSE()
				end
			else									-- スコアランクが"極"以外なら実行
				bufferScoreRank = "rank_"..g_scoreRank[this.player_]
				this.scoreRankMc_:SetVisible(true)
				this.scoreRankMc_.score_rank:GotoAndStop(bufferScoreRank)
				-- スキップONなら演出を飛ばして表示だけ行う
				if(this.isEffectSkip_ == true) then					
					this.scoreRankMc_:GotoAndStop("end")
					this.scoreRankMc_.score_rank_loop:GotoAndStop(bufferScoreRank)
					this.isDisplayScoreRank_ = true	
				-- スキップOFFかつスコアランク未表示なら、演出つきで表示する
				elseif(this.isDisplayScoreRank_ == false) then
					this.scoreRankMc_:GotoAndPlay("start")
					this.scoreRankMc_.score_rank_effect:GotoAndStop(bufferScoreRank)
					this.scoreRankMc_.score_rank_loop:GotoAndStop(bufferScoreRank)
					this.isDisplayScoreRank_ = true
					this:PlayScoreRankSE()
				end		
			end
		end,
		--　ここまでStartScoreRankDisplay

		
		
		
		
		
		PlayScoreRankSE = function(this)
			-- サウンド
			local scoreRankStr = "scorerank_"
			scoreRankNum = g_scoreRank[this.player_] + 1
			if(scoreRankNum == 10)then
				scoreRankStr = scoreRankStr..scoreRankNum
			else
				scoreRankStr = scoreRankStr.."0"..scoreRankNum
			end
			if(g_entryType == 2) then
				if(this.player_ == 1) then
					scoreRankStr = scoreRankStr.."_l"
				else
					scoreRankStr = scoreRankStr.."_r"
				end
			else
				scoreRankStr = scoreRankStr.."_c"
			end				
			TSound:Play("se_result_v12a",scoreRankStr)
		end,
		
		
		

		
			
		-- 王冠の表示指示を出す
		StartCrownDisplay = function(this)
			-- スキップONなら演出を飛ばしていきなり"end"に飛ばす
			if(this.isEffectSkip_ == true) then			
				if(g_crown[this.player_] == 1) then
					bufferCrown = "silver"
				elseif(g_crown[this.player_] == 2) then
					bufferCrown = "gold"		
				elseif(g_crown[this.player_] == 3) then
					bufferCrown = "rainbow"
				else
					bufferCrown = "non"
				end
			
				if(g_crown[this.player_] ~= 0) then
					this.crownMc_:SetVisible(true)
					this.crownMc_:GotoAndStop("end")
					this.crownMc_.crown:GotoAndStop(bufferCrown)
					this.crownMc_.crown_loop:GotoAndStop(bufferCrown)
				end	
				this.isDisplayCrown_ = true
			-- スキップOFFかつ王冠未表示なら、演出ありで"start"に飛ばす、ついでに音も鳴らす
			elseif(this.isDisplayCrown_ == false) then			
				if(g_crown[this.player_] == 1) then
					bufferCrown = "silver"
				elseif(g_crown[this.player_] == 2) then
					bufferCrown = "gold"		
				elseif(g_crown[this.player_] == 3) then
					bufferCrown = "rainbow"
				else
					bufferCrown = "non"
				end
			
				if(g_crown[this.player_] ~= 0) then
					this.crownMc_:SetVisible(true)
					this.crownMc_:GotoAndPlay("start")
					this.crownMc_.crown:GotoAndStop(bufferCrown)
					this.crownMc_.crown_loop:GotoAndStop(bufferCrown)
				end	
				this.isDisplayCrown_ = true				
				-- サウンド
				local crownStr = "crown_"
				if(g_crown[this.player_] == 1)then
					crownStr = crownStr.."silver"
				elseif(g_crown[this.player_] == 2)then
					crownStr = crownStr.."gold"
				elseif(g_crown[this.player_] == 3)then
					crownStr = crownStr.."rainbow"
				end
				if(g_entryType == 2) then
					if(this.player_ == 1) then
						crownStr = crownStr.."_l"
					else
						crownStr = crownStr.."_r"
					end
				else
					crownStr = crownStr.."_c"
				end				
				TSound:Play("se_result_v12a",crownStr)
			end
		end,
		-- ここまでStartCrownDisplay
		
		
		
		
		
		--　難易度の表示指示を出す
		StartDifficultyDisplay = function(this)
			num = g_difficulty[this.player_]
			bufferDifficulty = "difficulty_"..num
			this.difficultyMc_:SetVisible(true)
			this.difficultyMc_:GotoAndStop(bufferDifficulty)

			text = {"easy", "normal", "hard", "mania", "ura"}	
			str = "course_"..text[num + 1]		
			this.mc_:SetText("difficulty_mc","difficulty_text",str)
		end,	
		--　ここまでStartDifficultyDisplay

	}
end