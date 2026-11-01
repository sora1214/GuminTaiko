-- AiResultSongMain.lua
-- AIバトルリザルト画面:スコア部分
AiResultSongMain = {}

-- 使うクラスを読み込む
require("common.Sound")
require("common.State")
require("common.NamePlate")
require("ai_result.AiResultScoreCounter")
require("ai_result.AiResultBg")

-- このクラス

function AiResultSongMain.New()
	return
	{
		-- 定数
		kMaxGage_			= 50,	-- 魂ゲージの最大値
		kGageSpeed_			= 7,	-- 魂ゲージが１メモリ進むのに必要な時間
		--kWaitEffectEndTime_ = 500,	-- 全演出が終了してから入力を受け付けが再開するまでの待機時間
		kWaitEffectEndTime_ = 120,	-- 全演出が終了してから入力を受け付けが再開するまでの待機時間

		kScoreState = {
			-- スコア表示演出
			Num_		= 0,
			Score_		= 1,
			Best_		= 2,
		},

		-- 変数
		state_		= State.New("AiResultSongMain"),
		namePlate_	= NamePlate.New("name_plate_L"),
		bg_			= AiResultBg.New("bg_mc"),

		scoreNum_			= AiResultScoreCounter.New("totalScore"),
		scoreNumBack_		= AiResultScoreCounter.New("totalScoreBack"),
		goodNum_			= AiResultScoreCounter.New("goodNum"),
		okNum_				= AiResultScoreCounter.New("okNum"),
		badNum_				= AiResultScoreCounter.New("badNum"),
		maxcomboNum_		= AiResultScoreCounter.New("maxcomboNum"),
		dramrollNum_		= AiResultScoreCounter.New("dramrollNum"),
		updateScoreNum_		= AiResultScoreCounter.New("updateScore"),

		timer_					= 0,	-- 更新用タイマー

		currentTamashiiGage_	= 0,	-- 現在の魂ゲージ
		tamashiiGageTimer_		= 0,	-- 魂ゲージ専用タイマー

		scoreIndex_				= 0,	-- スコア更新用添え字
		scoreTimer_				= 0,	-- スコア更新用タイマー

		-- ムービークリップ
		mc_,					-- メインmc
		don1pMc_,				-- マイドン
		optionIconMc_,			-- 演奏オプションアイコン
		tamashiiGageMc_,		-- 魂ゲージ
		numMc_ = {},			-- 各スコア
		scoreNumMc_ = {},		-- 総合スコア
		donBack1pMc_,			-- スコアボード下部の背景
		donBackMain1pMc_,		-- スコアボード下部の背景の中身
		aiResultReward_,		-- ごほうび

		-- フラグ
		isEnd_			= false,
		isNewRecord_	= false,	-- ハイスコア演出を出す
		isEndScore_		= false,	-- スコア更新終了
		isEffectSkip_	= false,	-- true:スキップ使用可能, false:スキップ使用不可

		----------------------------------------
		-- state処理
		Init = function(this)
			-- 全体シーケンス
			this.state_.func_["Begin"] = function()
				-- 開始
				Debug.PrintString("[AiResultSongMain] Begin")
				this.state_:SetState("Loading")
			end

			this.state_.func_["Loading"] = function()
				-- 読み込み待ち

				if (Lumen.IsLoadMovieFinish() == true) then
					Debug.PrintString("[AiResultSongMain] Loading Finish")
					this.timer_ = 0
					this.state_:SetState("Wait")
					return
				end
				Debug.PrintString("[AiResultSongMain] Loading Wait...")
			end

			this.state_.func_["Wait"] = function()
				if(this.timer_ > 240) then
					Debug.PrintString("[AiResultSongMain] Wait Finish")
					-- 元の演出を1から出すタイプ
					--this.timer_ = 0
					--this.state_:SetState("UpdateScore")
					--this.isEffectSkip_ = true

					-- 演出全部最初から出すタイプ
					--this.timer_ = 0
					--this.isEffectSkip_ = false
					--this.state_:SetState("WaitEffectEnd")

					-- 一度待ってから、スコアを全部出すタイプ
					this.timer_ = 0
					this.isEffectSkip_ = false
					this.state_:SetState("EffectSkip")
					return
				end
				Debug.PrintString("[AiResultSongMain] Wait...")
			end

			this.state_.func_["UpdateScore"] = function()
				if(this.isEndScore_ == false)then
					this:UpdateScore()
				end

				if(this.timer_ > 500) then
					Debug.PrintString("[AiResultSongMain] UpdateScore Finish")
					this.timer_ = 0

					-- スコアランク再生
					this.state_:SetState("ScoreRank")
					this:StartScoreRank(false)
				end
			end

			this.state_.func_["ScoreRank"] = function()
				-- スコアランク表示

				if(this.timer_ > 150) then
					Debug.PrintString("[AiResultSongMain] ScoreRank Finish")
					this.timer_ = 0

					-- 王冠再生開始
					this.state_:SetState("Crown")
					this:StartCrown(false)
				end
			end

			this.state_.func_["Crown"] = function()
				-- 王冠表示

				if(this.timer_ > 150) then
					Debug.PrintString("[AiResultSongMain] Crown Finish")
					this.timer_ = 0
					this.isEffectSkip_ = false

					-- 演出完了後に移る
					this.state_:SetState("WaitEffectEnd")
					--this:StartDonMotion()		-- どんモーション再生
				end
			end

			this.state_.func_["EffectSkip"] = function()
				-- スキップ使用
				-- 演出完了後に移る
				this.state_:SetState("WaitEffectEnd")
				this:StartScoreRank(true)	-- スコアランク
				this:StartCrown(true)		-- 王冠
				this:SkipScore()			-- スコア

				-- ハイスコア
				if(g_isBestScore_ == true)then
					this:SkipHiScore()
				end
				--this:StartDonMotion()		-- どんモーション再生
				TSound:Play("se_common_v12a","don_c")	-- どんSE
			end

			this.state_.func_["WaitEffectEnd"] = function()
				-- 演出完了後の待機時間

				if(this.timer_ > this.kWaitEffectEndTime_) then
					Debug.PrintString("[AiResultSongMain] WaitEffectEnd Finish")
					this.timer_ = 0
					--this.state_:SetState("Reward")
					this.state_:SetState("End")
					this.aiResultReward_:SetStandardReward()

					--this.StayDonMotion()
				end
			end

			this.state_.func_["Reward"] = function()
				-- ごほうび演出
				if(this.aiResultReward_.isStandardEnd_ == true) then
					Debug.PrintString("[AiResultSongMain] Reward Finish")
					this.timer_ = 0
					this.state_:SetState("End")
				end
				this.aiResultReward_:Update()
			end

			this.state_.func_["End"] = function()
				Debug.PrintString("[AiResultSongMain] End")
				this.isEnd_ = true
			end
		end,

		-- 更新
		Update = function(this)
			-- ステート処理
			this.state_:Update()
			this.timer_ = this.timer_ + 1	--　タイマ更新

			--if(this.isEffectSkip_ == true and InputDon() == true)then
			--	-- スキップ
			--	this.timer_ = 0
			--	this.isEffectSkip_ = false
			--	this.state_:SetState("EffectSkip")
			--
			--	-- サウンド
			--	TSound:Play("se_common_v12a","don_c")
			--end
		end,

		-- 初期値の設定
		SetUp = function(this, mc, rewardMc)
			Debug.PrintString("[AiResultSongMain] SetUp")
			-- mcの設定
			this.mc_ = mc
			this.mc_:GotoAndStop("use_left")
			this.optionIconMc_ = mc.option_icon_L

			this.mc_.score_base_L.score_rank_mc:SetVisible(false)
			this.mc_.score_base_L.score_rank_kiwami_mc:SetVisible(false)
			this.mc_.score_base_L.crown_mc:SetVisible(false)

			this.aiResultReward_ = rewardMc

			-- 値の設定
			this:InitDon3D()
			this:SetBg()
			this:SetSongText()
			this:SetNamePlate()
			this:SetOptionIcon()
			this:SetDifficultyIcon()
			this:SetTamashiiGage()
			this:SetScore()
			this:SetHiscore()

			-- 仮の設定
			this:SkipTamashiiGage()		-- 魂ゲージ
			

			-- 演出をすべて一気に行う改修
			--this:StartScoreRank(true)	-- スコアランク
			--this:StartCrown(true)		-- 王冠
			--this:SkipScore()			-- スコア
			--if(g_isBestScore_ == true)then
			--	this:SkipHiScore()		-- ハイスコア
			--end
			--this:StartDonMotion()		-- どんモーション再生

			-- 演出を一度待ってからすべて出すタイプ
			this:StartDonMotion()		-- どんモーション再生
		end,

		-- LoadMovie
		LoadMovie = function(this)
			-- 読み込み
			this.bg_:LoadMovie()			-- 背景
			this.namePlate_:LoadMovie()		-- ネームプレート
			Lumen.LoadMovie("lumen/000_default/enso_normal/song_select/song_select_number_of_songs","song_number_info_mc")	-- 残り曲数表示
			Lumen.LoadMovie("lumen/000_default/enso_normal/enso/tamashiigage/tamashii_gage","tamashii_gage_L")		-- 魂ゲージ	
			Lumen.LoadMovie("lumen/000_default/common/option","option_icon_L")	-- 演奏オプションアイコン
			Lumen.LoadMovie("lumen/000_default/result/result_board_donback","dummy_donback_l")		-- どん背景1p
			
		end,

		----------------------------------------
		-- その他

		-- 背景の設定
		SetBg = function(this)
			this.bg_:Setup()
			-- this.bg_:SetPlayerInfo()

			-- スコアボードの下部背景
			this.donBack1pMc_ = this.mc_:GetChildMc("dummy_donback_l",true)
			this.donBackMain1pMc_ = this.donBack1pMc_:GetChildMc("donback",true)
			this.donBackMain1pMc_:GotoAndStop("1p")
		end,

		-- 曲のテキスト設定
		SetSongText = function(this)
			Debug.PrintString("[AiResultSongMain] SetSongText")
			-- 曲名
			this.mc_:SetText("song_name_center",g_songTitle_)

			-- 残り曲数表示MC
--			this.mc_.song_number_info_mc = this.m_MainMc:GetChildMc("song_number_info_mc",true)
			this.mc_.song_number_info_mc:SetText("main/number_of_songs","text_total_songs","attract_numberofstage")
			this.mc_.song_number_info_mc:SetText("main/number_of_songs","text_current_songs","attract_numberofsong")			
		end,

		-- ネームプレートの初期化
		SetNamePlate = function(this)
			Debug.PrintString("[AiResultSongMain] SetNamePlate")

			this.namePlate_:Setup()
			this.namePlate_:SetVisible(true)
			this.namePlate_:SetPlayerInfoAI(g_joinSide_)
		end,

		-- 3Dドンの初期化
		InitDon3D = function(this)
			Debug.PrintString("[AiResultSongMain] InitDon3D")
			
			this.mc_.don_L.event1p:SetVisible(false)
			this.mc_.don_L.event2p:SetVisible(false)
			this.mc_.don_L.don1p:SetVisible(true)
			this.mc_.don_L.don2p:SetVisible(false)

			--Don.SetLoopAnimation(0,"result_clear_loop",true)
			Don.ChangeDonForPlayData(0,Don.kType_Don)
			Don.SetLoopAnimation(0,"select_loop",true)
		end,

		-- どんモーション再生
		StartDonMotion = function(this)
			donSide = 0
			if(g_ensoResult_ == 0)then
				-- 失敗
				Don.SetNonLoopAnimation(0,"result_failure_p1",true)
				Don.SetLoopAnimation(0, "result_failure_loop_p1", true)
				--TSound:Play("voice_common_v12a","sad_c")				-- VO:どんモーションのボイス
			elseif(g_ensoResult_ == 1)then
				-- 成功
				Don.SetLoopAnimation(0,"result_clear",true)

				--TSound:Play("voice_common_v12a","atmos_clear_c")
				--TSound:Play("voice_common_v12a","glad_c")				-- VO:イエ～イ
			elseif(g_ensoResult_ == 2)then
				-- フルコンボ
				Don.SetLoopAnimation(0,"result_clear",true)

				--TSound:Play("voice_common_v12a","atmos_clear_c")
				--TSound:Play("voice_common_v12a","glad_c")				-- VO:イエ～イ
			elseif(g_ensoResult_ == 3)then
				-- ドンダフルコンボ
				Don.SetLoopAnimation(0,"result_clear",true)

				--TSound:Play("voice_common_v12a","atmos_clear_c")
				--TSound:Play("voice_common_v12a","glad_c")				-- VO:イエ～イ
			end
		end,

		-- どんモーションを待機モーションに戻す
		StayDonMotion = function(this)
			Don.SetLoopAnimation(0,"result_loop",true)
		end,

		-- 演奏オプションアイコンの初期化
		SetOptionIcon = function(this)
			Debug.PrintString("[AiResultSongMain] InitOptionIcon")
			this.optionIconMc_:GotoAndStop("menu")
			local index = 0
			-- 倍速オプション
			if(g_optionSpeed_ ~= 0) then
				buffStr = "option"..index
				targetMc = this.optionIconMc_:GetChildMc(buffStr,true)
				if(g_optionSpeed_ == 1) then targetMc:GotoAndStop("speedx1.1")
				elseif(g_optionSpeed_ == 2) then targetMc:GotoAndStop("speedx1.2")
				elseif(g_optionSpeed_ == 3) then targetMc:GotoAndStop("speedx1.3")
				elseif(g_optionSpeed_ == 4) then targetMc:GotoAndStop("speedx1.4")
				elseif(g_optionSpeed_ == 5) then targetMc:GotoAndStop("speedx1.5")
				elseif(g_optionSpeed_ == 6) then targetMc:GotoAndStop("speedx1.6")
				elseif(g_optionSpeed_ == 7) then targetMc:GotoAndStop("speedx1.7")
				elseif(g_optionSpeed_ == 8) then targetMc:GotoAndStop("speedx1.8")
				elseif(g_optionSpeed_ == 9) then targetMc:GotoAndStop("speedx1.9")
				elseif(g_optionSpeed_ == 10) then targetMc:GotoAndStop("speedx2")
				elseif(g_optionSpeed_ == 11) then targetMc:GotoAndStop("speedx2.5")
				elseif(g_optionSpeed_ == 12) then targetMc:GotoAndStop("speedx3")
				elseif(g_optionSpeed_ == 13) then targetMc:GotoAndStop("speedx3.5")
				elseif(g_optionSpeed_ == 14) then targetMc:GotoAndStop("speedx4")
				end
				index = index + 1
			end
			-- どろんオプション
			if(g_optionDron_ == true) then
				buffStr = "option"..index
				targetMc = this.optionIconMc_:GetChildMc(buffStr,true)
				targetMc:GotoAndStop("doron")
				index = index + 1
			end
			-- あべこべオプション
			if(g_optionReverse_ == true) then
				buffStr = "option"..index
				targetMc = this.optionIconMc_:GetChildMc(buffStr,true)
				targetMc:GotoAndStop("abekobe")
				index = index + 1
			end
			-- ランダムオプション
			if(g_optionRandomlv_ ~= 0) then
				buffStr = "option"..index
				targetMc = this.optionIconMc_:GetChildMc(buffStr,true)
				if(g_optionRandomlv_ == 1) then targetMc:GotoAndStop("kimagure")
				elseif(g_optionRandomlv_ == 2) then targetMc:GotoAndStop("detarame")
				end
				index = index + 1
			end
			-- 音符表示位置調整オプション
			if(g_optionNoteDrawAdjust_ ~= 0) then
				buffStr = "option"..index
				targetMc = this.optionIconMc_:GetChildMc(buffStr,true)
				targetMc:GotoAndStop("note_pos")
				index = index + 1
			end
		end,

		--　難易度アイコンの設定
		SetDifficultyIcon = function(this)
			Debug.PrintString("[AiResultSongMain] SetDifficultyIcon")
			local text	= {"easy", "normal", "hard", "mania", "ura"}
			local str	= "course_"..text[g_difficulty_ + 1]

			this.mc_.score_base_L.difficulty_mc:GotoAndStop("difficulty_"..g_difficulty_)
			this.mc_.score_base_L.difficulty_mc:SetText("difficulty_text",str)
		end,

		-- スコアランクの設定
		StartScoreRank = function(this, isSkip)
			Debug.PrintString("[AiResultSongMain] StartScoreRank")
			if(g_scoreRank_ == 0) then
				this.mc_.score_base_L.score_rank_mc:SetVisible(false)
				this.mc_.score_base_L.score_rank_kiwami_mc:SetVisible(false)
				return
			end

			if(g_scoreRank_ == 7) then	-- スコアランクが"極"なら実行
				this.mc_.score_base_L.score_rank_mc:SetVisible(false)
				this.mc_.score_base_L.score_rank_kiwami_mc:SetVisible(true)
				-- 演出開始
				if(isSkip == true)then
					-- スキップの場合
					this.mc_.score_base_L.score_rank_kiwami_mc:GotoAndStop("end")
				else
					-- 通常演出
					this.mc_.score_base_L.score_rank_kiwami_mc:GotoAndPlay("start")
					this:PlayScoreRankSE()
				end
			else						-- スコアランクが"極"以外なら実行
				bufferScoreRank = "rank_"..g_scoreRank_
				this.mc_.score_base_L.score_rank_mc:SetVisible(true)
				this.mc_.score_base_L.score_rank_kiwami_mc:SetVisible(false)

				-- 演出開始
				this.mc_.score_base_L.score_rank_mc.score_rank:GotoAndStop(bufferScoreRank)

				if(isSkip == true) then
					-- スキップ時
					this.mc_.score_base_L.score_rank_mc:GotoAndStop("end")
					this.mc_.score_base_L.score_rank_mc.score_rank_loop:GotoAndStop(bufferScoreRank)
				else
					-- 通常演出
					this.mc_.score_base_L.score_rank_mc:GotoAndPlay("start")
					this.mc_.score_base_L.score_rank_mc.score_rank_effect:GotoAndStop(bufferScoreRank)
					this.mc_.score_base_L.score_rank_mc.score_rank_loop:GotoAndStop(bufferScoreRank)
					this:PlayScoreRankSE()
				end
			end
		end,

		-- スコアランクのSE
		PlayScoreRankSE = function(this)
			Debug.PrintString("[AiResultSongMain] PlayScoreRankSE")
			local scoreRankStr = "scorerank_"
			scoreRankNum = g_scoreRank_ + 1
			if(scoreRankNum == 10)then
				scoreRankStr = scoreRankStr..scoreRankNum
			else
				scoreRankStr = scoreRankStr.."0"..scoreRankNum
			end
			scoreRankStr = scoreRankStr.."_c"			
			TSound:Play("se_result_v12a",scoreRankStr)
		end,

		-- ハイスコア演出が必要か否か判断
		SetHiscore = function(this)
			Debug.PrintString("[AiResultSongMain] SetHiscore")
			if(g_bestScore_ ~= 0 and g_scoreNum_ > g_bestScore_ and g_isAllOnpuEnd_ == true) then
				Debug.PrintString("ハイスコアあり")
				local updateScore = g_scoreNum_ - g_bestScore_
				this.isNewRecord_ = true
				this.mc_.score_base_L.best_score_mc:SetVisible(true)
				this.updateScoreNum_:Init(this.mc_.score_base_L.best_score_mc.best_score_num, 7, updateScore)
			end
		end,

		-- ハイスコア更新演出の再生
		StartHiscore = function(this)
			if(this.isNewRecord_ == true)then
				this.mc_.score_base_L.best_score_mc.best_score_text:SetText("text","result_bestscore")	-- 「ベストスコア更新！」テキスト
				this.updateScoreNum_:SkipCounter()
				this.mc_.score_base_L.best_score_mc:GotoAndPlay("start")
				-- ボイス「ベスト更新！」
				TSound:Play("voice_result_v12a","bestscore_c")
			end
		end,

		-- ハイスコアスキップ時
		SkipHiScore = function(this)
			if(this.isNewRecord_ == true)then
				this.mc_.score_base_L.best_score_mc.best_score_text:SetText("text","result_bestscore")	-- 「ベストスコア更新！」テキスト
				this.updateScoreNum_:SkipCounter()
				this.mc_.score_base_L.best_score_mc:GotoAndPlay("start")
				-- ボイス「ベスト更新！」
				TSound:Play("voice_result_v12a","bestscore_c")
			end
		end,

		-- 王冠の設定
		StartCrown = function(this, isSkip)
			Debug.PrintString("[AiResultSongMain] StartCrown")	
			local bufferCrown = "non"

			if(g_crown_ == 1) then
				bufferCrown = "silver"
			elseif(g_crown_ == 2) then
				bufferCrown = "gold"		
			elseif(g_crown_ == 3) then
				bufferCrown = "rainbow"
			end
		
			if(g_crown_ ~= 0) then
				this.mc_.score_base_L.crown_mc:SetVisible(true)
				this.mc_.score_base_L.crown_mc.crown:GotoAndStop(bufferCrown)
				this.mc_.score_base_L.crown_mc.crown_loop:GotoAndStop(bufferCrown)

				if(isSkip == true)then
					this.mc_.score_base_L.crown_mc:GotoAndStop("end")
				else
					this.mc_.score_base_L.crown_mc:GotoAndPlay("start")

					-- サウンド再生
					local crownStr = "crown_"..bufferCrown.."_c"
					TSound:Play("se_result_v12a",crownStr)
				end
			end
		end,

		--　魂ゲージの設定
		SetTamashiiGage = function(this)
			Debug.PrintString("[AiResultSongMain] SetTamashiiGage")
			local text	= {"easy", "normal", "normal", "hard", "hard"}
			local num	= g_difficulty_
			local label	= "result_"..text[num + 1]

			if(g_entryType_ == 0) then
				label = label.."_1p"
			elseif(g_entryType_ == 1) then
				label = label.."_2p"
			end

			Debug.PrintString("[AiResultSongMain] label = "..label)
			Debug.PrintString("[AiResultSongMain] num = "..num)
			this.mc_.tamashii_gage_L:GotoAndStop(label)
			this.tamashiiGageMc_ = this.mc_.tamashii_gage_L:GetChildMc(label,true)
			this.tamashiiGageMc_.clear_text:SetText("text","clear")
		end,

		-- 魂ゲージの更新
		UpdateTamashiiGage = function(this)
			Debug.PrintString("[AiResultSongMain] UpdateTamashiiGage")
			this.tamashiiGageTimer_ = this.tamashiiGageTimer_ + 1	-- 専用タイマを毎フレーム動かす
			-- カレントメモリ数がｃ++から受け取ったゲージ数以下、かつ専用タイマがゲージ増加スピード*カレントメモリ数を超えたら実行
			if(this.currentTamashiiGage_ < g_tamashiiGage_ and this.tamashiiGageTimer_ > this.kGageSpeed_ * this.currentTamashiiGage_) then
				this.currentTamashiiGage_ = this.currentTamashiiGage_ + 1
				gageNumLabel = "gage_"..this.currentTamashiiGage_
				this.tamashiiGageMc_:GotoAndStop(gageNumLabel)
				-- 魂ゲージが満タンになったら、虹色エフェクトと炎エフェクトを起動する
				if(this.currentTamashiiGage_ == this.kMaxGage_) then
					this.tamashiiGageMc_.rainbow:GotoAndPlay("fever_start")
					this.tamashiiGageMc_.fire:GotoAndPlay("fever_start")
					-- 満タン専用SEを鳴らす
--					if(idx == 1 and (g_entryType_ == 0 or g_entryType_ == 2)) then
--						TSound:Play("se_result_v12a","achieve_tamashii_l")
--					else
--						TSound:Play("se_result_v12a","achieve_tamashii_r")
--					end
				end
			end

			-- カレントメモリ数がｃ++から受け取ったゲージ数に到達したら、ゲージ増加中のSEを消す
			if(this.currentTamashiiGage_ == g_tamashiiGage_) then
				-- TSound:StopSlot(idx)
			end
			
			-- 更新完了を観測
			if(this.currentTamashiiGage_ == g_tamashiiGage_) then
				-- this.isEndTamashiiGage_ = true
			end
		end,

		--　魂ゲージの演出スキップ
		SkipTamashiiGage = function(this)
			Debug.PrintString("[AiResultSongMain] StartTamashiiGage")
			local label = "gage_"..g_tamashiiGage_
			this.tamashiiGageMc_:GotoAndStop(label)
			this.currentTamashiiGage_ = g_tamashiiGage_
			-- TSound:StopSlot(idx)
			-- 魂ゲージが満タンの場合は、虹色エフェクトと炎エフェクトを起動する
			if(this.currentTamashiiGage_ == this.kMaxGage_) then
				this.tamashiiGageMc_.rainbow:GotoAndPlay("fever_start")
				this.tamashiiGageMc_.fire:GotoAndPlay("fever_start")
			end
		end,

		-- スコアの設定
		SetScore = function(this)
			Debug.PrintString("[AiResultSongMain] SetScore")
			this.mc_.score_base_L:SetText("score_text","result_score")	
			this.scoreNum_:Init(this.mc_.score_base_L.total_score_mc, 7, g_scoreNum_)
			this.scoreNumBack_:Init(this.mc_.score_base_L.total_score_back_mc, 7, g_scoreNum_)
			this.goodNum_:Init(this.mc_.score_base_L.good_num_mc, 4, g_goodNum_)
			this.okNum_:Init(this.mc_.score_base_L.ok_num_mc, 4, g_okNum_)
			this.badNum_:Init(this.mc_.score_base_L.bad_num_mc, 4, g_badNum_)
			this.dramrollNum_:Init(this.mc_.score_base_L.dramroll_num_mc, 4, g_dramrollNum_)
			this.maxcomboNum_:Init(this.mc_.score_base_L.max_combo_num_mc, 4, g_maxcomboNum_)

			this.numMc_[1] = this.goodNum_
			this.numMc_[2] = this.okNum_
			this.numMc_[3] = this.badNum_
			this.numMc_[4] = this.dramrollNum_
			this.numMc_[5] = this.maxcomboNum_

			this.scoreNumMc_[1] = this.scoreNum_
			this.scoreNumMc_[2] = this.scoreNumBack_

			this.scoreIndex_ = this.kScoreState.Num_
		end,

		-- スコアの演出
		UpdateScore = function(this)
			-- 最初のロール
			if(this.scoreTimer_ == 0 and this.scoreIndex_ == this.kScoreState.Num_) then
				-- 全てロール
				for idx = 1, 5 do
			 		this.numMc_[idx]:StartRoll()
				end

				for idx = 1, 2 do
			 		this.scoreNumMc_[idx]:StartRoll()
				end
			end

			this.scoreTimer_ = this.scoreTimer_ + 1
			if(this.scoreTimer_ > 50 and this.scoreIndex_ == this.kScoreState.Num_) then
				-- 良・可・不可・連打数・最大コンボ数の表示
				for idx = 1, 5 do
			 		this.numMc_[idx]:SkipCounter()
				end

				this.scoreTimer_ = 0
				this.scoreIndex_ = this.kScoreState.Score_
				-- サウンド
				TSound:Play("se_common_v12a","count_stop_c")
			elseif(this.scoreTimer_ > 120 and this.scoreIndex_ == this.kScoreState.Score_) then
				-- スコアの表示
				for idx = 1, 2 do
					this.scoreNumMc_[idx]:SkipCounter()
				end
				this.scoreTimer_ = 0
				this.scoreIndex_ = this.kScoreState.Best_
				-- サウンド
				TSound:Play("se_common_v12a","don_big")

			elseif(this.scoreTimer_ > 120 and this.scoreIndex_ == this.kScoreState.Best_) then
				if(g_isBestScore_ == true)then
					this:StartHiscore()
				end
				this.isEndScore_ = true
				--TSound:Play("se_common_v12a","don_big")
			end
		end,

		-- スコアの演出スキップ
		SkipScore = function(this)
			Debug.PrintString("[AiResultSongMain] SkipScore")
			if(this.isEndScore_ == false)then
				-- 全てロール
				for idx = 1, 5 do
					this.numMc_[idx]:SkipCounter()
				end
	
				for idx = 1, 2 do
					this.scoreNumMc_[idx]:SkipCounter()
				end
				this.isEndScore_ = true
			end
		end,

		-- ご褒美開始
		StartReward = function(this)
			Debug.PrintString("[AiResultSongMain] StartReward")
			-- this.aiResultReward_:DebugSetStart()
		end,
	}
end
