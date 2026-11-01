-- DaniResultTotalMain.lua
-- 段位リザルト各曲画面
DaniResultTotalMain = {}

-- 使うクラスを読み込む
require("common.Sound")
require("common.State")
require("dani_result.DaniResultTotalBase")
require("dani_result.DaniResultDetailBase")

-- このクラス
function DaniResultTotalMain.New()
	return
	{
		-- ムービークリップ
		mainMc_,
		stampMc_,	-- 合否スタンプ

		-- 定数
		kWaitTime_		= 0.5*Common.FPS,	-- 待機時間
		kWaitDetail_	= 0.2*Common.FPS,	-- 詳細リザルトを1お題分終了後の待機時間
		kWaitEndTime_	= 30*Common.FPS,	-- 待機終了時間

		-- インスタンス
		totalBase_,
		detailBase_ = {},

		-- 変数
		state_ = State.New("DaniResultTotalMain"),

		currentDetailNum_	= 1,		-- 現在表示している詳細リザルト
		maxDetailNum_		= 3,		-- 詳細リザルトの最大数(1~3)
		currentTime_		= 0,		-- 時間

		--フラグ
		isEnd_ = false,
		isStampEnd_ = false,

		LoadMovie = function(this)
			-- LoadMovie
			Lumen.LoadMovie("lumen/000_default/enso_dani/enso/tamashiigauge/tamashii_gauge","total_mc/dummy_tamashii_gauge")	-- 魂ゲージ

			-- TODO:お題がいくつでもスタンプ押下時に全部スライドインしてしまうので対策
			-- フラッシュで対策できるのであればしたい
			for idx = 1, g_maxOdaiNum_ do
				Lumen.LoadMovie("lumen/000_default/enso_dani/result/dani_result_detail","total_detail_0"..idx.."_mc/dummy_detail")
			end

			-- Lumen.LoadMovie("lumen/000_default/enso_dani/result/dani_result_detail","total_detail_01_mc/dummy_detail")			-- お題1
			-- Lumen.LoadMovie("lumen/000_default/enso_dani/result/dani_result_detail","total_detail_02_mc/dummy_detail")			-- お題2
			-- Lumen.LoadMovie("lumen/000_default/enso_dani/result/dani_result_detail","total_detail_03_mc/dummy_detail")			-- お題3
		end,

		Init = function(this)
			-- 全体シーケンス
			Debug.PrintString("[DaniResultTotalMain] Init")

			this.state_.func_["Begin"] = function()
				-- 開始
				Debug.PrintString("[DaniResultTotalMain] Begin")

				this.currentTime_		= 0
				this.isEnd_				= false
				this.currentDetailNum_	= 1
				this.maxDetailNum_		= g_maxOdaiNum_
				this.state_:SetState("Loading")
			end

			this.state_.func_["Loading"] = function()
				-- 読み込み待ち

				if (Lumen.IsLoadMovieFinish() == true) then
					Debug.PrintString("[DaniResultTotalMain] Loading Finish")

					-- MovieClip
					this.mainMc_ = Lumen.GetMovieClip("main_mc",true)
					this.mainMc_:GotoAndPlay("total")

					-- インスタンス生成
					-- 総合リザルト
					this:SetUpResultTotal()

					-- 詳細リザルト
					this:SetUpResultDetail()

					this.state_:SetState("TotalSlideIn")
					TSound:Play("se_daniresult_v12e","total_intro")		-- SE
					return
				end
				Debug.PrintString("[DaniResultTotalMain] Loading Wait...")
			end

			this.state_.func_["TotalSlideIn"] = function()
				-- 総合リザルトスライドイン
				if(InputDon() == true)then
					-- スキップ処理
					Debug.PrintString("[DaniResultTotalMain] SlideIn Finish")
					this.state_:SetState("TotalSkip")
					return
				end

				if(this.mainMc_:IsInCurrentLabelMc("" ,"end_total") == true)then
					Debug.PrintString("[DaniResultTotalMain] SlideIn Finish")

					-- カウントアップ開始
					this.totalBase_:StartCountUp()

					this.state_:SetState("TotalCountUp")
					return
				end
			end

			this.state_.func_["TotalCountUp"] = function()
				-- 総合リザルトカウントアップ
				if( InputDon() == true)then
					-- スキップ処理
					Debug.PrintString("[DaniResultTotalMain] TotalCountUp Finish")
					this.state_:SetState("TotalSkip")
					return
				end

				if( this.totalBase_.isScoreCountUpEnd_ == true and this.totalBase_.isGaugeCountUpEnd_ == true)then
					Debug.PrintString("[DaniResultTotalMain] TotalCountUp Finish")

					--this.mainMc_:GotoAndPlay("detail_in_01")
					--this.state_:SetState("DetailSlideIn")
					this.state_:SetState("TotalEndWait")
					return
				end

				-- 更新
				this.totalBase_:UpdateCountUp()
			end

			this.state_.func_["TotalSkip"] = function()
				-- 総合リザルトスキップ処理
				this.mainMc_:GotoAndStop("end_total")
				this.totalBase_:SkipCountUp()

				--this.state_:SetState("TotalEndWait")
				this.state_:SetState("DetailSkip")
			end

			this.state_.func_["TotalEndWait"] = function()
				-- 総合リザルト終了後の待機時間
				this.currentTime_ = this.currentTime_ + 1
				if(this.currentTime_ < this.kWaitDetail_)then
					-- スコアがすべてカウントした後、少しだけ入力開始に猶予を持たせる
					return
				end

				if(InputDon() == true or this.currentTime_ >= this.kWaitDetail_)then
					-- 待機終了
					this.currentTime_ = 0
					if(this.maxDetailNum_ > 0)then
						-- お題がある場合
						this.mainMc_:GotoAndPlay("detail_in_01")
						this.state_:SetState("DetailSlideIn")
					else
						-- ない場合
						this.mainMc_:GotoAndStop("stamp")
						this.state_:SetState("DetailEndWait")
					end
				end

			end

			this.state_.func_["DetailSlideIn"] = function()
				-- 詳細リザルトスライドイン
				if( InputDon() == true)then
					-- スキップ処理
					Debug.PrintString("[DaniResultTotalMain] SlideIn Finish")
					this.state_:SetState("DetailSkip")
					return
				end

				if(this.mainMc_:IsInCurrentLabelMc("" ,"end_detail_0"..this.currentDetailNum_) == true)then
					Debug.PrintString("[DaniResultTotalMain] SlideIn Finish")

					-- カウントアップ開始
					this.currentTime_ = 0
					--this.detailBase_[this.currentDetailNum_]:StartCountUp()
					this.detailBase_[this.currentDetailNum_]:StartCountUpGauge()
					this.detailBase_[this.currentDetailNum_]:StartNumIn()
					Debug.PrintString("CountUp Start")
					this.state_:SetState("DetailCountUp")
					return
				end
			end

			this.state_.func_["DetailCountUp"] = function()
				-- 詳細リザルトカウントアップ
				if( InputDon() == true)then
					-- スキップ処理
					Debug.PrintString("[DaniResultTotalMain] DetailCountUp Finish")
					this.state_:SetState("DetailSkip")
					return
				end

				if( this.detailBase_[this.currentDetailNum_].isScoreCountUpEnd_ == true and this.detailBase_[this.currentDetailNum_].isGaugeCountUpEnd_)then
					-- カウントアップ完了後
					Debug.PrintString("[DaniResultTotalMain] DetailCountUp Finish")

					-- 待機時間
					this.currentTime_ = this.currentTime_ + 1
					if(this.currentTime_ < this.kWaitDetail_)then
						return
					end

					this.currentDetailNum_ = this.currentDetailNum_ + 1

					if(this.currentDetailNum_ > this.maxDetailNum_)then
						-- 最大値を超えた場合
						this.state_:SetState("DetailEndWait")
					else
						-- 次の詳細リザルトを表示します
						this.mainMc_:GotoAndPlay("detail_in_0"..this.currentDetailNum_)
						this.state_:SetState("DetailSlideIn")
					end

					return
				end

				-- カウントアップ更新
				this.detailBase_[this.currentDetailNum_]:UpdateCountUp()
			end

			this.state_.func_["DetailSkip"] = function()
				-- 詳細リザルトスキップ
				-- this.mainMc_:GotoAndStop("end_detail_03")
				this.mainMc_:GotoAndStop("stamp")

				for idx = 1, this.maxDetailNum_ do
					this.detailBase_[idx]:ScoreSkip()
					this.detailBase_[idx]:GaugeSkip()
				end

				this.state_:SetState("DetailEndWait")
			end

			this.state_.func_["DetailEndWait"] = function()
				-- 詳細リザルト終了後の待機時間
				this.currentTime_ = this.currentTime_ + 1
				if(this.currentTime_ < this.kWaitTime_)then
					-- スコアがすべてカウントした後、少しだけ入力開始に猶予を持たせる
					return
				end

				if(InputDon() == true or this.currentTime_ >= this.kWaitDetail_)then
					-- 待機終了
					this.currentTime_ = 0
					this.mainMc_:GotoAndPlay("stamp")
					--this:SetOdaiResult()
					this:SetUpStampMc()
					this:SetUpResultBg()
					this:StampSE()
					this.stampMc_:GotoAndPlay("stamp_anm")
					this.state_:SetState("stamp")
				end

			end

			this.state_.func_["stamp"] = function()
				-- 合否スタンプ

				this.currentTime_ = this.currentTime_ + 1
				if(this.currentTime_ < this.kWaitTime_)then
					-- スコアがすべてカウントした後、少しだけ入力開始に猶予を持たせる
					return
				end

				if(this.mainMc_:IsInCurrentLabelMc("" ,"end_stamp") == true)then
					if(this.isStampEnd_ == false)then
						this.isStampEnd_ = true
						this:StampVoice()
						this:StampMotion()
					end

					if(InputDon() == true or this.currentTime_ >= this.kWaitEndTime_)then
						this.state_:SetState("End")
					end
				end
			end

			this.state_.func_["End"] = function()
				this.isEnd_ = true
			end
		end,

		-- 更新
		Update = function(this)
			-- ステート処理
			this.state_:Update()
		end,

		-- 総合リザルトの設定
		SetUpResultTotal = function(this)
			Debug.PrintString("SetUpResultTotal")
			this.totalBase_ = DaniResultTotalBase.New(this.mainMc_.total_mc)
			
			-- SetUp用の値を算出
			gauge		= g_tamashiiGauge_
			gaugeValue	= g_tamashiiGaugeValue_
			gaugeBorder	= g_gaugeBorder_
			gaugeBorderValue	= g_gaugeBorderValue_
			score		= g_totalScore_[1]	+ g_totalScore_[2]	+ g_totalScore_[3]		-- 総合スコア
			bestScore	= g_HiScore_[1] + g_HiScore_[2] + g_HiScore_[3]					-- 総合ベストスコア
			ryo			= g_goodNum_[1]		+ g_goodNum_[2]		+ g_goodNum_[3]			-- 良
			ka			= g_okNum_[1]		+ g_okNum_[2]		+ g_okNum_[3]			-- 可
			fuka		= g_badNum_[1]		+ g_badNum_[2]		+ g_badNum_[3]			-- 不可
			renda		= g_dramrollNum_[1] + g_dramrollNum_[2] + g_dramrollNum_[3]		-- 連打数
			combo		= g_maxComboNum_												-- 最大コンボ数
			totalHit	= ryo + ka + renda												-- 叩いた数

			Debug.PrintString("g_gaugeBorder_"..g_gaugeBorder_)
			Debug.PrintString("g_gaugeBorderValue_"..g_gaugeBorderValue_)
			this.totalBase_:SetUp(gauge, gaugeValue, gaugeBorder, gaugeBorderValue, score, bestScore, ryo, ka, fuka, renda, combo, totalHit)
			this.totalBase_:Init()
		end,

		-- 詳細リザルトの設定
		SetUpResultDetail = function(this)
			for idx = 1, this.maxDetailNum_ do
				this.detailBase_[idx] = DaniResultDetailBase.New(this.mainMc_:GetChildMc("total_detail_0"..idx.."_mc",true))

				-- SetUp = function(this, detailType, gaugeType,clearType, odaiBorder, odaiNum)
				this.detailBase_[idx]:SetUp(idx, g_odaiType_[idx], g_odaiGaugeType_[idx],g_odaiClearType_[idx], g_odaiBorder_[idx], g_odaiGoodBorder_[idx], g_odaiNum_[idx])
				this.detailBase_[idx]:Init()
			end
		end,

		-- お題に対する結果を設定
		SetOdaiResult = function(this)
			Debug.PrintString("SetOdaiResult")
			local check		= this:CheckResult()
			local okNum		= g_okNum_[1] + g_okNum_[2]	+ g_okNum_[3]		-- 可
			local badNum	= g_badNum_[1] + g_badNum_[2] + g_badNum_[3]	-- 不可

			if(check == 2)then
				-- 大成功
				if(badNum == 0)then
					if(okNum == 0)then
						-- ドンダフルコンボ
						g_odaiResult_ = 6
					else
						-- フルコンボ
						g_odaiResult_ = 5
					end
				else
					g_odaiResult_ = 4
				end
			elseif(check == 1)then
				-- 合格
				if(badNum == 0)then
					if(okNum == 0)then
						-- ドンダフルコンボ
						g_odaiResult_ = 3
					else
						-- フルコンボ
						g_odaiResult_ = 2
					end
				else
					g_odaiResult_ = 1
				end
			else
				-- 不合格
				g_odaiResult_ = 0
			end

			Debug.PrintString("g_odaiResult_ : "..g_odaiResult_)
		end,

		-- 合否スタンプの設定
		SetUpStampMc = function(this)
			Debug.PrintString("SetUpStampMc")

			-- 設定
			if(g_odaiResult_ == 0)then this.stampMc_ = this.mainMc_.stamp_anm_fail_mc			-- 失敗
			elseif(g_odaiResult_ == 1)then this.stampMc_ = this.mainMc_.stamp_anm_red_01_mc		-- 合格
			elseif(g_odaiResult_ == 2)then this.stampMc_ = this.mainMc_.stamp_anm_red_02_mc		-- 合格フルコンボ
			elseif(g_odaiResult_ == 3)then this.stampMc_ = this.mainMc_.stamp_anm_red_03_mc		-- 合格ドンダフルコンボ
			elseif(g_odaiResult_ == 4)then this.stampMc_ = this.mainMc_.stamp_anm_gold_01_mc	-- 大成功合格
			elseif(g_odaiResult_ == 5)then this.stampMc_ = this.mainMc_.stamp_anm_gold_02_mc	-- 大成功合格フルコンボ
			elseif(g_odaiResult_ == 6)then this.stampMc_ = this.mainMc_.stamp_anm_gold_03_mc	-- 大成功合格ドンダフルコンボ
			end
		end,

		-- スタンプ押下前のSE
		StampSE = function(this)
			if(g_odaiResult_ == 0)then
				TSound:Play("se_daniresult_v12e","notclear")			-- SE
			elseif(g_odaiResult_ >= 1 and g_odaiResult_ <= 3)then
				TSound:Play("se_daniresult_v12e","clear_normal")		-- SE
			elseif(g_odaiResult_ >= 4 and g_odaiResult_ <= 6)then
				TSound:Play("se_daniresult_v12e","clear_upper")			-- SE
			end
		end,

		-- スタンプ押下時のボイス
		StampVoice = function(this)
			Debug.PrintString("StampVoice")
			if(g_odaiResult_ == 0)then
				TSound:Play("voice_daniresult_v12e","notclear")			-- Voice:「不合格だドン…」
			elseif(g_odaiResult_ >= 1 and g_odaiResult_ <= 3)then
				TSound:Play("se_daniresult_v12e","atmos_clear_c")		-- SE: 歓声
				TSound:Play("voice_daniresult_v12e","clear_normal")		-- Voice:「合格だドン！」
			elseif(g_odaiResult_ >= 4 and g_odaiResult_ <= 6)then
				TSound:Play("se_daniresult_v12e","atmos_clear_c")		-- SE: 歓声
				TSound:Play("voice_daniresult_v12e","clear_upper")		-- Voice:「合格だド～ン！！　（す、すごいドン！！）」
			end
		end,

		-- スタンプ押下時のどんモーション
		StampMotion = function(this)
			Debug.PrintString("StampMotion")
			local donSide
			if (g_joinSide_ == 1) then donSide = 0 end
			if (g_joinSide_ == 2) then donSide = 1 end

			donSide = 0
			if(g_odaiResult_ == 0)then
				Don.SetNonLoopAnimation(0,"result_failure",false)
				Don.SetLoopAnimation(0,"result_failure_loop",true)
			elseif(g_odaiResult_ >= 1 and g_odaiResult_ <= 3)then
				Don.SetNonLoopAnimation(0,"result_clear",false)
				--Don.SetLoopAnimation(0,"result_loop",true)
				Don.SetLoopAnimation(0,"result_clear_loop",true)
			elseif(g_odaiResult_ >= 4 and g_odaiResult_ <= 6)then
				Don.SetNonLoopAnimation(0,"result_full",false)
				Don.SetLoopAnimation(0,"result_full_loop",true)
			end
		end,

		-- リザルト背景の設定
		SetUpResultBg = function(this)
			Debug.PrintString("SetUpResultBg")
			
			-- 設定
			if(g_odaiResult_ == 0)then this.mainMc_.result_bg_mc:GotoAndStop("bg_fail")			-- 失敗
			elseif(g_odaiResult_ == 1)then this.mainMc_.result_bg_mc:GotoAndStop("bg_red_01")	-- 合格
			elseif(g_odaiResult_ == 2)then this.mainMc_.result_bg_mc:GotoAndStop("bg_red_02")	-- 合格フルコンボ
			elseif(g_odaiResult_ == 3)then this.mainMc_.result_bg_mc:GotoAndStop("bg_red_03")	-- 合格ドンダフルコンボ
			elseif(g_odaiResult_ == 4)then this.mainMc_.result_bg_mc:GotoAndStop("bg_gold_01")	-- 大成功合格
			elseif(g_odaiResult_ == 5)then this.mainMc_.result_bg_mc:GotoAndStop("bg_gold_02")	-- 大成功合格フルコンボ
			elseif(g_odaiResult_ == 6)then this.mainMc_.result_bg_mc:GotoAndStop("bg_gold_03")	-- 大成功合格ドンダフルコンボ
			end
		end,

		-- 合否チェック
		CheckResult = function(this)
			Debug.PrintString("CheckResult")
			local ok	= 0
			local good	= 0
			local check = {}

			-- 詳細リザルト
			for idx = 1, this.maxDetailNum_ do
				check[idx] = this.detailBase_[idx]:CheckResult()
			end
			-- 魂ゲージ
			check[this.maxDetailNum_+1] = this.totalBase_:CheckResult()

			for idx = 1, this.maxDetailNum_+1 do
				Debug.PrintString("check : "..check[idx])
			end

			for idx = 1, this.maxDetailNum_+1 do
				if(check[idx] == 1)then
					ok = ok+1
				elseif(check[idx] == 2)then
					good = good+1
				end
			end

			-- 判定
			if(good == this.maxDetailNum_+1)then
				return 2
			elseif((ok + good) == this.maxDetailNum_+1)then
				return 1
			else
				return 0
			end
		end,
	}
end