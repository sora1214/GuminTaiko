-- DaniResultTotalBase.lua
-- 段位リザルト総合ベース
DaniResultTotalBase = {}

-- 使うクラスを読み込む
require("dani_result.DaniResultSongScore")

-- このクラス
function DaniResultTotalBase.New(McInstance)
	return
	{
		-- ムービークリップ
		mainMc_ = McInstance,	-- total_mc

		-- 定数
		kGaungeMax_		= 50,	-- 魂ゲージの最大値
		kGaungeMaxValue_= 100,	-- 魂ゲージの最大値

		--kGaugeSpeed_	= 4,				-- 魂ゲージが1メモリ進むのに必要な時間
		kGaugeSpeed_	= 2,				-- 魂ゲージが1メモリ進むのに必要な時間
		kGaugeNumWait_	= 0.5*Common.FPS,	-- 魂ゲージ実数値表示後の待機時間

		-- 変数
		gauge_				= 0,	-- 魂ゲージ
		gaugeNum_			= 0,	-- 魂ゲージ実数値
		currentGauge_		= 0,	-- 現在のゲージ
		currentGaugeValue_	= 0,	-- 現在のゲージの実数値
		gaugeBorder_		= 0,	-- 魂ゲージの成功値(0~50)
		gaugeBorderValue_	= 0,	-- 魂ゲージの成功実数値(0~100)
		gaugeTimer_			= 0,	-- 魂ゲージ用タイマー

		totalCounter_		= {},	-- 総合スコアカウンター
		counter_			= {},	-- スコアカウンター
		gaugeCounter_		= {},	-- 魂ゲージの実数値カウンター
		bestScoreCounter_	= {},	-- ベストスコアカウンター
		
		-- スコア
		counter_bestScore_			= 0,	-- ベストスコア
		counter_score_				= 0,	-- 総合スコア
		counter_ryo_				= 0,	-- 良
		counter_ka_					= 0,	-- 可
		counter_fuka_				= 0,	-- 不可
		counter_renda_				= 0,	-- 連打数
		counter_combo_				= 0,	-- 最大コンボ数
		counter_totalHit_			= 0,	-- 叩けた数

		-- フラグ
		isGaugeMax_			= false,		-- ゲージ最大判定 : true:最大, false:最大ではない
		isScoreCountUp_		= false,		-- スコアカウントアップ演出中
		isScoreCountUpEnd_	= false,		-- スコアカウントアップ完了
		isGaugeCountUp_		= false,		-- ゲージカウントアップ演出中
		isGaugeCountUpEnd_	= false,		-- ゲージカウントアップ完了
		isGaugeNumCountUp_	= false,		-- ゲージの実数値カウントアップ演出中

		SetUp = function(this, gauge, gaugeValue, gaugeBorder, gaugeBorderValue, score, bestScore, ryo, ka, fuka, renda, combo, totalHit)
			-- 初期設定
			--if(gauge ~= 0)then
			--	this.gauge_	= (gauge/30000)*50
			--	this.gauge_ = math.floor(this.gauge_+0.5)
			--
			--	this.gaugeNum_ = (gauge/30000)*100
			--	this.gaugeNum_ = math.floor(this.gaugeNum_+0.5)
			--else
			--	this.gauge_				= 0
			--end

			this.gauge_	= gauge
			this.gaugeNum_ = gaugeValue

			Debug.PrintString("this.gauge_ = "..this.gauge_)
			Debug.PrintString("this.gaugeNum_ = "..this.gaugeNum_)

			this.gaugeBorder_		= gaugeBorder
			this.gaugeBorderValue_	= gaugeBorderValue

			this.counter_score_		= score
			this.counter_ryo_		= ryo
			this.counter_ka_		= ka
			this.counter_fuka_		= fuka
			this.counter_renda_		= renda
			this.counter_combo_		= combo
			this.counter_totalHit_	= totalHit

			this.counter_bestScore_ = score - bestScore

			Debug.PrintString("counterScore : "..this.counter_score_)
		end,

		Init = function(this)
			-- 初期化
			Debug.PrintString("[DaniResultTotalBase] Init")

			-- 初期化
			this:InitGauge()
			this:InitScore()
			this:ScoreSkip()
		end,

		InitGauge = function(this)
			-- 魂ゲージの初期化
			Debug.PrintString("InitGauge")

			this.mainMc_.dummy_tamashii_gauge:GotoAndStop("dani_result")								-- 魂ゲージをリザルト用に設定
			this.mainMc_.dummy_tamashii_gauge.gauge_mc:GotoAndStop("border_"..this.gaugeBorder_)		-- ボーダーラインの設定
			this.mainMc_.dummy_tamashii_gauge.gauge_mc.tamashii_mc:GotoAndStop("not_clear")				-- 「魂」文字:not_clear/clear/fever_startの三種類
			this.mainMc_.dummy_tamashii_gauge.gauge_mc.gauge_border:GotoAndStop("dani_result")			-- ゲージ上の情報を段位リザルト用に変更
			this.mainMc_.dummy_tamashii_gauge.gauge_mc.gauge_lamp_mc:GotoAndStop("gage_0")				-- ゲージのゲージ：gage_0～50まで
			this.mainMc_.dummy_tamashii_gauge.gauge_mc.gauge_bg:GotoAndStop("bg_"..g_joinSide_.."p")	-- ゲージの背景の色を設定
			this.mainMc_.dummy_tamashii_gauge.gauge_mc.gauge_lamp_mc.lamp:GotoAndStop("lamp_"..g_joinSide_.."p")		-- ゲージの色:lamp_1p/lamp_2p/lamp_clear

			-- ベストスコア
			this.mainMc_.total_score_mc.best_score_mc:GotoAndStop("init")
			this.mainMc_.total_score_mc.best_score_mc.best_score_text:SetText("text","hiscore_update")
			--best_score_text
			

			-- テキスト設定
			this.mainMc_.txt_theme_name:SetText("tx_detail_label","clear_theme_soul_gauge")	-- 魂ゲージ
			this.mainMc_.dummy_tamashii_gauge.gauge_mc.gauge_border:SetText("tx_border","requirement_soul_gauge")	-- 魂ゲージの値
			this.mainMc_.total_score_mc:SetText("tx_score_label","clear_theme_score")								-- スコア

			-- フラグ
			this.isGaugeCountUp_	= false
			this.isGaugeCountUpEnd_	= false

			-- 魂ゲージの実数値
			this.gaugeCounter_[1] = DaniResultSongScore.New()
			this.gaugeCounter_[1]:Init(this.mainMc_.dummy_tamashii_gauge.gauge_mc.gauge_lamp_mc.gauge_result_num_mc.gauge_result_num_set_mc.gauge_result_add_mc, 3, this.gaugeNum_)

			this.gaugeCounter_[2] = DaniResultSongScore.New()
			this.gaugeCounter_[2]:Init(this.mainMc_.dummy_tamashii_gauge.gauge_mc.gauge_lamp_mc.gauge_result_num_mc.gauge_result_num_set_mc.gauge_result_front_mc, 3, this.gaugeNum_)

			this.gaugeCounter_[3] = DaniResultSongScore.New()
			this.gaugeCounter_[3]:Init(this.mainMc_.dummy_tamashii_gauge.gauge_mc.gauge_lamp_mc.gauge_result_num_mc.gauge_result_num_set_mc.gauge_result_back_mc, 3, this.gaugeNum_)
		end,

		InitScore = function(this)
			-- スコアの初期化
			Debug.PrintString("InitScore")

			-- 総合スコアカウンター
			-- front
			this.totalCounter_[1] = DaniResultSongScore.New()
			this.totalCounter_[1]:Init(this.mainMc_.total_score_mc.total_score_front_mc, 7, this.counter_score_)
			
			-- back
			this.totalCounter_[2] = DaniResultSongScore.New()
			this.totalCounter_[2]:Init(this.mainMc_.total_score_mc.total_score_back_mc, 7, this.counter_score_)

			-- ベストスコアカウンター
			this.bestScoreCounter_ = DaniResultSongScore.New()
			if(this.counter_bestScore_ > 0 and g_isBestScore_ == true)then
				this.bestScoreCounter_:Init(this.mainMc_.total_score_mc.best_score_mc.best_score_num, 7, this.counter_bestScore_)
			end

			-- スコアカウンター
			-- 良
			this.counter_[1] = DaniResultSongScore.New()
			this.counter_[1]:Init(this.mainMc_.total_count_01_mc.total_ryo, 4, this.counter_ryo_)

			-- 可
			this.counter_[2] = DaniResultSongScore.New()
			this.counter_[2]:Init(this.mainMc_.total_count_01_mc.total_ka, 4, this.counter_ka_)

			-- 不可
			this.counter_[3] = DaniResultSongScore.New()
			this.counter_[3]:Init(this.mainMc_.total_count_01_mc.total_fuka, 4, this.counter_fuka_)

			-- 連打数
			this.counter_[4] = DaniResultSongScore.New()
			this.counter_[4]:Init(this.mainMc_.total_count_02_mc.total_renda, 4, this.counter_renda_)

			-- コンボ数
			this.counter_[5] = DaniResultSongScore.New()
			this.counter_[5]:Init(this.mainMc_.total_count_02_mc.total_combo, 4, this.counter_combo_)

			-- 叩けた数
			this.counter_[6] = DaniResultSongScore.New()
			this.counter_[6]:Init(this.mainMc_.total_count_02_mc.total_hit, 4, this.counter_totalHit_)

			-- フラグ
			this.isScoreCountUp_		= false
			this.isScoreCountUpEnd_		= false
		end,

		StartCountUp = function(this)
			-- カウントアップ開始

			-- 総合スコアカウンター
			for idx = 1, 2 do
				this.totalCounter_[idx]:StartCounter()
			end

			-- ベストスコアカウンター
			this.bestScoreCounter_:SkipCounter()

			-- スコアカウンター
			for idx = 1, 6 do
				this.counter_[idx]:StartCounter()
			end

			-- 魂ゲージ実数値カウンター
			for idx = 1, 3 do
				this.gaugeCounter_[idx]:SkipCounter()
			end

			-- SE再生
			if(this.gaugeNum_ ~= this.currentGaugeValue_)then
				TSound:PlaySlot("se_common_v12a", "count_up_loop_c", 0)
			end

			this.isScoreCountUp_ = true
			this.isGaugeCountUp_ = true

			-- ハイスコアのスタート開始
			if(this.counter_bestScore_ > 0 and g_isBestScore_ == true)then
				this.mainMc_.total_score_mc.best_score_mc:GotoAndPlay("start")
			end
		end,

		UpdateCountUp = function(this)
			-- カウントアップ更新
			if(this.isGaugeCountUp_ == true)then
				-- 魂ゲージの更新
				this:UpdateGauge()
			elseif(this.isGaugeNumCountUp_ == true)then
				-- 魂ゲージの実数値を更新
				this:UpdateGaugeNum()
			else
				-- ディレイ
				this.gaugeTimer_ = this.gaugeTimer_ + 1
				if(this.gaugeTimer_ > this.kGaugeNumWait_)then
					this.isGaugeCountUpEnd_ = true
				end
			end
			--this:UpdateScore()		-- スコアの更新
		end,

		SkipCountUp = function(this)
			-- カウントアップ演出のスキップ
			this:GaugeSkip()
			this:ScoreSkip()
		end,

		UpdateGauge = function(this)
			-- 魂ゲージの更新
			if(this.gaugeNum_ == this.currentGaugeValue_)then
				Debug.PrintString("UpdateGauge finish")
				-- ゲージの更新完了
				this.isGaugeCountUp_ = false

				TSound:StopSlot(0)
				if(this.gauge_ == this.kGaungeMax_)then
					TSound:Play("se_result_v12a","achieve_tamashii_c")
				end

				-- 魂ゲージの実数値更新開始
				this.mainMc_.dummy_tamashii_gauge.gauge_mc.gauge_lamp_mc.gauge_result_num_mc:GotoAndPlay("num_in")
				this.isGaugeNumCountUp_ = true
				return
			end

			this.isGaugeCountUp_ = true
			this.gaugeTimer_ = this.gaugeTimer_ + 1
			if(this.gaugeTimer_ > this.kGaugeSpeed_)then
				
				-- 魂ゲージ増加
				this.gaugeTimer_ = 0
				this.currentGaugeValue_ = this.currentGaugeValue_+1
				if(this.currentGaugeValue_ ~= 0)then
					this.currentGauge_ = this.currentGaugeValue_ / 2
					this.currentGauge_ = math.floor(this.currentGauge_)
				end
				this.mainMc_.dummy_tamashii_gauge.gauge_mc.gauge_lamp_mc:GotoAndStop("gage_"..this.currentGauge_)

				-- ゲージの色を更新
				this:GaugeLampUpdate()
				this:GaugeNumColorUpdate()
			end
		end,

		UpdateGaugeNum = function(this)
		Debug.PrintString("UpdateGaugeNum")
			-- 魂ゲージの実数値を設定
			if(this.mainMc_.dummy_tamashii_gauge.gauge_mc.gauge_lamp_mc.gauge_result_num_mc:IsInCurrentLabelMc("", "wait") == true)then
				-- 実数値表示完了
				Debug.PrintString("UpdateGaugeNum finish")
				this.isGaugeNumCountUp_ = false
			end
		end,

		GaugeSkip = function(this)
			-- ゲージスキップ演出時
			Debug.PrintString("GaugeSkip")
			this.currentGaugeValue_ = this.gaugeNum_
			if(this.currentGaugeValue_ ~= 0)then
				this.currentGauge_ = this.currentGaugeValue_ / 2
				this.currentGauge_ = math.floor(this.currentGauge_)
			end
			this.mainMc_.dummy_tamashii_gauge.gauge_mc.gauge_lamp_mc:GotoAndStop("gage_"..this.currentGauge_)
			this.mainMc_.dummy_tamashii_gauge.gauge_mc.gauge_lamp_mc.gauge_result_num_mc:GotoAndStop("wait")
			this:GaugeLampUpdate()
			this:GaugeNumColorUpdate()

			-- 魂ゲージ実数値カウンター
			for idx = 1, 3 do
				this.gaugeCounter_[idx]:SkipCounter()
			end

			-- ハイスコア
			if(this.counter_bestScore_ > 0 and g_isBestScore_ == true)then
				-- 表示
				this.mainMc_.total_score_mc.best_score_mc:GotoAndStop("end")
				this.bestScoreCounter_:SkipCounter()
			else
				-- 非表示
				this.mainMc_.total_score_mc.best_score_mc:GotoAndStop("init")
				this.bestScoreCounter_:SkipCounter()
			end

			TSound:StopSlot(0)
			if(this.gauge_ == this.kGaungeMax_)then
				TSound:Play("se_result_v12a","achieve_tamashii_c")
			end

			this.isGaugeCountUp_		= false
			this.isGaugeNumCountUp_		= false
			this.isGaugeCountUpEnd_		= true
		end,

		GaugeLampUpdate = function(this)
			-- ゲージ発光制御用mc
			glowMc = this.mainMc_.dummy_tamashii_gauge.gauge_mc:GetChildMc("glow_"..this.currentGauge_, true)

			-- ゲージ増加時の発行演出
			--glowMc:GotoAndPlay("start")

			if(this.currentGaugeValue_ == this.kGaungeMaxValue_)then
				-- 魂ゲージが最大
				if(this.isGaugeMax_ == false)then
					this.isGaugeMax_ = true
					glowMc.gauge_lamp_glow_type_mc:GotoAndPlay("lamp_clear")									-- 発光ゲージの色
					this.mainMc_.dummy_tamashii_gauge.gauge_mc.gauge_lamp_mc.lamp:GotoAndStop("lamp_clear")		-- ゲージの色:lamp_1p/lamp_2p/lamp_clear
					this.mainMc_.dummy_tamashii_gauge.gauge_mc.tamashii_mc:GotoAndPlay("fever_start")			-- 「魂」文字:not_clear/clear/fever_startの三種類

				end

			elseif(this.currentGaugeValue_ >= this.gaugeBorderValue_)then
				-- 魂ゲージがクリア値を超えている場合(クリア時)
				glowMc.gauge_lamp_glow_type_mc:GotoAndPlay("lamp_clear")									-- 発光ゲージの色
				this.mainMc_.dummy_tamashii_gauge.gauge_mc.gauge_lamp_mc.lamp:GotoAndStop("lamp_clear")		-- ゲージの色:lamp_1p/lamp_2p/lamp_clear
				this.mainMc_.dummy_tamashii_gauge.gauge_mc.tamashii_mc:GotoAndStop("clear")					-- 「魂」文字:not_clear/clear/fever_startの三種類

			else
				-- 超えていない場合(未クリア時)
				glowMc.gauge_lamp_glow_type_mc:GotoAndPlay("lamp_1p")										-- 発光ゲージの色
				this.mainMc_.dummy_tamashii_gauge.gauge_mc.gauge_lamp_mc.lamp:GotoAndStop("lamp_"..g_joinSide_.."p")		-- ゲージの色:lamp_1p/lamp_2p/lamp_clear
				this.mainMc_.dummy_tamashii_gauge.gauge_mc.tamashii_mc:GotoAndStop("not_clear")				-- 「魂」文字:not_clear/clear/fever_startの三種類

			end
		end,

		GaugeNumColorUpdate = function(this)
			-- ゲージの実数値制御用mc
			glowMc = this.mainMc_.dummy_tamashii_gauge.gauge_mc.gauge_lamp_mc.gauge_result_num_mc:GetChildMc("gauge_result_num_set_mc", true)

			if(this.currentGaugeValue_ == this.kGaungeMaxValue_)then
				-- 魂ゲージが最大
				glowMc:GotoAndStop("max")
			elseif(this.currentGaugeValue_ >= this.gaugeBorderValue_)then
				-- 魂ゲージがクリア値を超えている場合(クリア時)
				glowMc:GotoAndStop("clear")
			elseif(this.currentGaugeValue_ > 0)then
				-- 超えていない場合(未クリア時)
				glowMc:GotoAndStop("noclear_"..g_joinSide_.."p")
			else
				-- 魂ゲージが0
				glowMc:GotoAndStop("empty")
			end
		end,

		UpdateScore = function(this)
			-- スコアの更新
			local countEnd = 0

			-- 総合スコアカウンター
			for idx = 1, 2 do
				this.totalCounter_[idx]:Update()
				if(this.totalCounter_[idx].isEnd_ == true)then
					countEnd = countEnd + 1
				end
			end

			-- スコアカウンター
			for idx = 1, 6 do
				this.counter_[idx]:Update()
				if(this.counter_[idx].isEnd_ == true)then
					countEnd = countEnd + 1
				end
			end

			if(countEnd == 8)then
				-- カウントアップ完了判定
				this.isScoreCountUp_		= false
				this.isScoreCountUpEnd_		= true
			end
		end,

		ScoreSkip = function(this)
			-- スコアスキップ演出時
			Debug.PrintString("counterScore : "..this.counter_score_)
			for idx = 1, 2 do
				this.totalCounter_[idx]:SkipCounter()
			end
			for idx = 1, 6 do
				this.counter_[idx]:SkipCounter()
			end

			this.isScoreCountUp_		= false
			this.isScoreCountUpEnd_		= true
		end,

		CheckResult = function(this)
			-- 合否チェック(魂ゲージの合否)
			-- 0:不合格, 1:合格, 2:大成功合格
			Debug.PrintString("[DaniResultTotalBase]CheckResult")

			if(this.currentGaugeValue_ >= this.gaugeBorderValue_)then
				
				if(this.currentGaugeValue_ == this.kGaungeMaxValue_)then
					return 2
				end

				return 1
			end

			return 0
		end,

	}
end