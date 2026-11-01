-- DaniResultDetailBase.lua
-- 段位リザルト詳細ベース
DaniResultDetailBase = {}

-- 使うクラスを読み込む
require("common.Sound")
require("dani_result.DaniResultSongScore")

function DaniResultDetailBase.New(McInstance)
	return
	{
		-- ムービークリップ
		mainMc_ = McInstance,		-- total_detail_00_mc
		gaugeMc_,					-- ゲージ
		scoreMc_,					-- スコア
		gaugeDeteilMc_ = {},		-- 各ゲージ
		scoreDeteilMc_ = {},		-- 各スコア

		-- 定数
		kGaugeMax_		= 100,	-- ゲージの最大値
		kGaugeSpeed_	= 1,	-- ゲージが1メモリ進むのに必要な時間
		kNumInWait_		= 60,	-- スコアのカウント終了後の待機時間

		-- インスタンス
		score_ = {},

		-- 変数
		detailNum_			= 0,	-- 詳細スコアの番号 : 1～3
		detailType_			= 0,	-- お題の種類 : 0:3曲累計, 1:1曲目, 2:2曲目, 3:3曲分
		clearType_			= {},	-- お題のクリア条件
		odaiBorder_			= {},	-- お題の成功ライン
		odaiGoodBorder_		= {},	-- お題の大成功ライン
		odaiGaugeGoodBorder_= {},	-- ゲージの大成功値
		odaiNum_			= {},	-- お題に対する成績

		allScoreFront_		= {},	-- 前面
		allScoreBack_		= {},	-- 背面
		allScoreAdd_		= {},	-- add
		detailScoreFront_	= {},	-- 詳細スコア前面
		detailScoreBack_	= {},	-- 詳細スコア背面
		detailScoreAdd_		= {},	-- add

		gaugeType_			= 0,	-- ゲージのタイプ(0:type_up, 1:type_down)
		gauge_				= 0,	-- ゲージの値
		currentGauge_		= 0,	-- 現在のゲージの値
		gaugeTimer_			= 0,	-- ゲージ用タイマー

		detailGauge_		= {},	-- ゲージの値
		detailCurrentGauge_	= {},	-- 現在のゲージの値
		detailGaugeTimer_	= {},	-- ゲージ用タイマー

		numInEndTimer_		= 0,	-- スコアのカウント終了後のカウント
		
		-- フラグ
		isScoreCountUp_		= false,	-- スコアカウントアップ演出中
		isScoreCountUpEnd_	= false,	-- スコアカウントアップ演出終了フラグ
		isGaugeCountUp_		= false,	-- ゲージカウントアップ演出中
		isGaugeCountUpEnd_	= false,	-- ゲージカウントアップ演出終了フラグ
		isUnreach_			= false,	-- 未到達演出中

		SetUp = function(this, detailNum, detailType, gaugeType,clearType, odaiBorder, odaiGoodBorder, odaiNum)
			-- 初期設定
			this.detailNum_			= detailNum
			this.gaugeType_			= gaugeType
			this.detailType_		= detailType
			this.clearType_			= clearType
			this.odaiBorder_		= odaiBorder
			this.odaiGoodBorder_	= odaiGoodBorder
			this.odaiNum_			= odaiNum
		end,

		Init = function(this)
			Debug.PrintString("[DaniResultDetailBase] Init")

			this.isScoreCountUp_		= false
			this.isScoreCountUpEnd_		= false
			this.isGaugeCountUp_		= false
			this.isGaugeCountUpEnd_		= false

			-- テキスト設定

			-- お題名の設定
			if(this.clearType_ == 0)then
				-- None
			elseif(this.clearType_ == 1)then
				-- 魂ゲージ
			elseif(this.clearType_ == 2)then
				this.mainMc_.dummy_detail.detail_mc.txt_theme_name:SetText("tx_detail_label","clear_theme_ryo")			-- 良
			elseif(this.clearType_ == 3)then
				this.mainMc_.dummy_detail.detail_mc.txt_theme_name:SetText("tx_detail_label","clear_theme_ka")			-- 可
			elseif(this.clearType_ == 4)then
				this.mainMc_.dummy_detail.detail_mc.txt_theme_name:SetText("tx_detail_label","clear_theme_fuka")		-- 不可
			elseif(this.clearType_ == 5)then
				this.mainMc_.dummy_detail.detail_mc.txt_theme_name:SetText("tx_detail_label","clear_theme_combo")		-- コンボ
			elseif(this.clearType_ == 6)then
				this.mainMc_.dummy_detail.detail_mc.txt_theme_name:SetText("tx_detail_label","clear_theme_renda")		-- 連打数
			elseif(this.clearType_ == 7)then
				this.mainMc_.dummy_detail.detail_mc.txt_theme_name:SetText("tx_detail_label","clear_theme_score")		-- スコア
			elseif(this.clearType_ == 8)then
				this.mainMc_.dummy_detail.detail_mc.txt_theme_name:SetText("tx_detail_label","clear_theme_total_hit")	-- たたけた数
			end

			-- お題の種類を設定
			if(this.detailType_ == 0)then
				-- all:累計お題の場合
				this:InitDetailAll()

			elseif(g_maxReachNum_ == 1)then
				this.mainMc_.dummy_detail.detail_mc:GotoAndStop("1st")
				this:InitDetail(1)
				
			elseif(g_maxReachNum_ == 2)then
				this.mainMc_.dummy_detail.detail_mc:GotoAndStop("2nd")
				this:InitDetail(2)

			elseif(g_maxReachNum_ == 3)then
				this.mainMc_.dummy_detail.detail_mc:GotoAndStop("3rd")
				this:InitDetail(3)

			end

		end,

		InitDetailAll = function(this)
			Debug.PrintString("InitDetailAll")

			-- 最終的なゲージの値
			this.gauge_ = 100
			if(this.odaiBorder_[1] == 0)then
				this.gauge_ = math.floor(100 * (this.odaiNum_[1] / 1))
			else
				this.gauge_ = math.floor(100 * (this.odaiNum_[1] / this.odaiBorder_[1]))
				-- 大成功以上となるゲージの算出
				this.odaiGaugeGoodBorder_[1] = 100 - math.floor(100 * (this.odaiGoodBorder_[1] / this.odaiBorder_[1]))
				Debug.PrintString("this.odaiGaugeGoodBorder_ : "..this.odaiGaugeGoodBorder_[1])
			end
			Debug.PrintString("this.gauge_ : "..this.gauge_)
			if(this.gauge_ > 100)then
				this.gauge_ = 100
			end

			-- allタイプ初期化
			this.mainMc_.dummy_detail.detail_mc:GotoAndStop("all")

			-- 数値出現制御 : init/num_in/wait
			-- this.mainMc_.dummy_detail.detail_mc.score_all_mc:GotoAndStop("wait")
			this.mainMc_.dummy_detail.detail_mc.score_all_mc:GotoAndStop("init")
			this.scoreMc_ = this.mainMc_.dummy_detail.detail_mc.score_all_mc

			-- 数値前面
			fromtMc = this.mainMc_.dummy_detail.detail_mc.score_all_mc.score_l_gauge_num_mc.score_l_front_mc
			this.allScoreFront_ = DaniResultSongScore.New()
			
			-- 数値背面
			backMc = this.mainMc_.dummy_detail.detail_mc.score_all_mc.score_l_gauge_num_mc.score_l_back_mc
			this.allScoreBack_ = DaniResultSongScore.New()

			-- 数値Add
			addMc = this.mainMc_.dummy_detail.detail_mc.score_all_mc.score_l_gauge_num_mc.score_l_add_mc
			this.allScoreAdd_ = DaniResultSongScore.New()

			-- ゲージバーの設定

			-- ゲージバーの種類を設定 : type_up/type_down 
			gaugeType = this.mainMc_.dummy_detail.detail_mc.score_all_mc.score_l_gauge_bar_mc.score_com_gauge_bar_type_mc
			if(this.gaugeType_ == 0)then
				-- UPゲージバー : gauge_0~100(100で最大)
				if(this.odaiBorder_[1] == 0)then
					-- 成功値が0で場合クリアの特殊処理
					this.gauge_ = 100
				end

				this.gaugeMc_ = this.mainMc_.dummy_detail.detail_mc.score_all_mc.score_l_gauge_bar_mc.score_com_gauge_bar_type_mc.score_com_gauge_bar_up_mc
				this.gaugeMc_:GotoAndStop("gauge_0")
				gaugeType:GotoAndStop("type_up")

				-- 数値の色設定 : empty/up_50/up_80/up_100/down_80/down_100/max
				numMc = this.mainMc_.dummy_detail.detail_mc.score_all_mc.score_l_gauge_num_mc
				numMc:GotoAndStop("empty")

				-- テキスト設定
				this.mainMc_.dummy_detail.detail_mc.score_all_mc:SetText("tx_border","requirement_or_higher_"..this.detailNum_.."_1")	-- お題条件

				-- 数値の設定
				local s = string.format(this.odaiNum_[1])
				this.allScoreFront_:Init(fromtMc, #s, this.odaiNum_[1])
				this.allScoreBack_:Init(backMc, #s, this.odaiNum_[1])
				this.allScoreAdd_:Init(addMc, #s, this.odaiNum_[1])

				gaugeMaxType = this.mainMc_.dummy_detail.detail_mc.score_all_mc.score_l_gauge_bar_mc
				gaugeMaxType:GotoAndStop("init")
			else
				-- DOWNゲージバー : gauge_100~0(100で最大)
				this.currentGauge_ = 100		-- ゲージ最大から開始
				this.gauge_ = 100 - this.gauge_
				if(this.gauge_ < 0)then
					-- ゲージの値が0以下
					this.gauge_ = 0
				end
				this.gaugeMc_ = this.mainMc_.dummy_detail.detail_mc.score_all_mc.score_l_gauge_bar_mc.score_com_gauge_bar_type_mc.score_com_gauge_bar_down_mc
				this.gaugeMc_:GotoAndStop("gauge_100")
				gaugeType:GotoAndStop("type_down")

				-- 数値の色設定 : empty/up_50/up_80/up_100/down_80/down_100/max
				numMc = this.mainMc_.dummy_detail.detail_mc.score_all_mc.score_l_gauge_num_mc
				numMc:GotoAndStop("down_100")

				-- テキスト設定
				this.mainMc_.dummy_detail.detail_mc.score_all_mc:SetText("tx_border","requirement_less_than_"..this.detailNum_.."_1")	-- お題条件

				-- 数値の設定
				local odaiIndex = this.odaiBorder_[1] - this.odaiNum_[1]
				if(odaiIndex < 0)then odaiIndex = 0 end
				local s = string.format(odaiIndex)

				Debug.PrintString("odaiIndex"..odaiIndex)
				Debug.PrintString("odaiBorder_[idx]"..this.odaiBorder_[1])
				Debug.PrintString("odaiNum_[idx]"..this.odaiNum_[1])
				this.allScoreFront_:Init(fromtMc, #s, odaiIndex)
				this.allScoreBack_:Init(backMc, #s, odaiIndex)
				this.allScoreAdd_:Init(addMc, #s, odaiIndex)

				gaugeMaxType = this.mainMc_.dummy_detail.detail_mc.score_all_mc.score_l_gauge_bar_mc
				gaugeMaxType:GotoAndStop("down_100")
			end
		end,

		InitDetail = function(this, num)
			Debug.PrintString("InitDetail")
			for idx = 1, num do
				-- 最終的なゲージの値
				if(this.odaiBorder_[idx] == 0)then
					this.detailGauge_[idx] = math.floor(100 * (this.odaiNum_[idx] / 1))
				else
					this.detailGauge_[idx] = math.floor(100 * (this.odaiNum_[idx] / this.odaiBorder_[idx]))
					-- 大成功以上となるゲージの算出
					this.odaiGaugeGoodBorder_[idx] = 100 - math.floor(100 * (this.odaiGoodBorder_[idx] / this.odaiBorder_[idx]))
					Debug.PrintString("this.odaiGaugeGoodBorder_ : "..this.odaiGaugeGoodBorder_[idx])
				end
				Debug.PrintString("this.detailGauge_ : "..this.detailGauge_[idx])
				if(this.detailGauge_[idx] > 100)then
					this.detailGauge_[idx] = 100
				end

				this.detailGaugeTimer_[idx]		= 0

				-- スコアのメインMCを取得
				detailMc = this.mainMc_.dummy_detail.detail_mc:GetChildMc("score_0"..idx.."_mc",true)
				this.scoreDeteilMc_[idx] = detailMc

				-- 数値出現制御 : init/num_in/wait
				detailMc:GotoAndStop("wait")
				--detailMc:GotoAndPlay("num_in")

				-- スコア値の制御

				-- 前面
				this.detailScoreFront_[idx] = DaniResultSongScore.New()
				
				-- 背面
				this.detailScoreBack_[idx] = DaniResultSongScore.New()

				-- 背面
				this.detailScoreAdd_[idx] = DaniResultSongScore.New()

				-- ゲージ
				-- ゲージバーの種類を設定 : type_up/type_down
				gaugeType = detailMc.score_m_gauge_bar_mc.score_com_gauge_bar_type_mc
				if(this.gaugeType_ == 0)then
					-- UPゲージバー : gauge_0~100(100で最大)
					if(this.odaiBorder_[idx] == 0)then
						-- 成功値が0で場合クリアの特殊処理
						this.detailGauge_[idx] = 100
					end

					this.detailCurrentGauge_[idx] = 0
					this.gaugeDeteilMc_[idx] = detailMc.score_m_gauge_bar_mc.score_com_gauge_bar_type_mc.score_com_gauge_bar_up_mc
					this.gaugeDeteilMc_[idx]:GotoAndStop("gauge_0")
					gaugeType:GotoAndStop("type_up")

					-- 数値の色設定 : empty/up_50/up_80/up_100/down_80/down_100/max
					numMc = detailMc.score_m_gauge_num_mc
					numMc:GotoAndStop("empty")

					-- テキスト設定
					detailMc:SetText("tx_border","requirement_or_higher_"..this.detailNum_.."_"..idx)	-- お題条件

					-- 数値の設定
					local s = string.format(this.odaiNum_[idx])
					this.detailScoreFront_[idx]:Init(detailMc.score_m_gauge_num_mc.score_m_front_mc, #s, this.odaiNum_[idx])
					this.detailScoreBack_[idx]:Init(detailMc.score_m_gauge_num_mc.score_m_back_mc, #s, this.odaiNum_[idx])
					this.detailScoreAdd_[idx]:Init(detailMc.score_m_gauge_num_mc.score_m_add_mc, #s, this.odaiNum_[idx])

					gaugeMaxType = detailMc.score_m_gauge_bar_mc
					gaugeMaxType:GotoAndStop("init")
				else
					-- DOWNゲージバー : gauge_100~0(100で最大)
					this.detailCurrentGauge_[idx] = 100		-- ゲージ最大から開始
					this.detailGauge_[idx] = 100 - this.detailGauge_[idx]
					if(this.detailGauge_[idx] < 0)then
						-- ゲージの値が0以下
						this.detailGauge_[idx] = 0
					end
					this.gaugeDeteilMc_[idx] = detailMc.score_m_gauge_bar_mc.score_com_gauge_bar_type_mc.score_com_gauge_bar_down_mc
					this.gaugeDeteilMc_[idx]:GotoAndStop("gauge_100")
					gaugeType:GotoAndStop("type_down")

					-- 数値の色設定 : empty/up_50/up_80/up_100/down_80/down_100/max
					numMc = detailMc.score_m_gauge_num_mc
					numMc:GotoAndStop("down_100")

					-- テキスト設定
					detailMc:SetText("tx_border","requirement_less_than_"..this.detailNum_.."_"..idx)	-- お題条件

					-- 数値の設定
					
					local odaiIndex = this.odaiBorder_[idx] - this.odaiNum_[idx]
					if(odaiIndex < 0)then odaiIndex = 0 end
					local s = string.format(odaiIndex)
					Debug.PrintString("idx"..idx)
					Debug.PrintString("odaiIndex"..odaiIndex)
					Debug.PrintString("odaiBorder_[idx]"..this.odaiBorder_[idx])
					Debug.PrintString("odaiNum_[idx]"..this.odaiNum_[idx])
					this.detailScoreFront_[idx]:Init(detailMc.score_m_gauge_num_mc.score_m_front_mc, #s, odaiIndex)
					this.detailScoreBack_[idx]:Init(detailMc.score_m_gauge_num_mc.score_m_back_mc, #s, odaiIndex)
					this.detailScoreAdd_[idx]:Init(detailMc.score_m_gauge_num_mc.score_m_add_mc, #s, odaiIndex)

					gaugeMaxType = detailMc.score_m_gauge_bar_mc
					gaugeMaxType:GotoAndStop("down_100")
				end
			end
		end,

		StartCountUp = function(this)
			-- カウントアップ開始
			Debug.PrintString("[DaniResultDetailBase] StartCountUp")
			if(this.detailType_ == 0)then
				this.allScoreFront_:StartCounter()
				this.allScoreBack_:StartCounter()
				this.allScoreAdd_:StartCounter()
				-- カウントアップ完了判定
				if(this.allScoreFront_.isEnd_ == true)then
					this.isScoreCountUpEnd_ = true
				end

				Debug.PrintString("gauge_ =" ..this.gauge_)
				Debug.PrintString("currentGauge_ = "..this.currentGauge_)
				if(this.gauge_ ~= this.currentGauge_)then
					if(this.gaugeType_ == 0)then
						Debug.PrintString("SE再生1")
						TSound:PlaySlot("se_daniresult_v12e","gauge_up_loop", 0)		-- SE
					else
						Debug.PrintString("SE再生2")
						TSound:PlaySlot("se_daniresult_v12e","gauge_down_loop", 0)		-- SE
					end
				end
			else
				local seFlag = false
				for idx = 1, g_maxReachNum_ do
					this.detailScoreFront_[idx]:StartCounter()
					this.detailScoreBack_[idx]:StartCounter()
					this.detailScoreAdd_[idx]:StartCounter()

					Debug.PrintString("this.detailGauge_[idx] =" ..this.detailGauge_[idx])
					Debug.PrintString("this.detailCurrentGauge_[idx] = "..this.detailCurrentGauge_[idx])
					if(this.detailGauge_[idx] ~= this.detailCurrentGauge_[idx])then
						seFlag = true
					end
				end

				if(seFlag == true)then
					if(this.gaugeType_ == 0)then
						Debug.PrintString("SE再生3")
						TSound:PlaySlot("se_daniresult_v12e","gauge_up_loop", 0)		-- SE
					else
						Debug.PrintString("SE再生4")
						TSound:PlaySlot("se_daniresult_v12e","gauge_down_loop", 0)		-- SE
					end
				end
			end
		end,

		StartCountUpGauge = function(this)
			Debug.PrintString("[DaniResultDetailBase] StartCountUpGauge")
			if(this.detailType_ == 0)then

				Debug.PrintString("gauge_ =" ..this.gauge_)
				Debug.PrintString("currentGauge_ = "..this.currentGauge_)
				if(this.gauge_ ~= this.currentGauge_)then
					if(this.gaugeType_ == 0)then
						TSound:PlaySlot("se_daniresult_v12e","gauge_up_loop", 0)		-- SE
					else
						TSound:PlaySlot("se_daniresult_v12e","gauge_down_loop", 0)		-- SE
					end
				end
			else
				local seFlag = false
				for idx = 1, g_maxReachNum_ do
					Debug.PrintString("this.detailGauge_[idx] =" ..this.detailGauge_[idx])
					Debug.PrintString("this.detailCurrentGauge_[idx] = "..this.detailCurrentGauge_[idx])
					if(this.detailGauge_[idx] ~= this.detailCurrentGauge_[idx])then
						seFlag = true
					end
				end

				if(seFlag == true)then
					if(this.gaugeType_ == 0)then
						TSound:PlaySlot("se_daniresult_v12e","gauge_up_loop", 0)		-- SE
					else
						TSound:PlaySlot("se_daniresult_v12e","gauge_down_loop", 0)		-- SE
					end
				end
			end
		end,

		StartNumIn = function(this)
			Debug.PrintString("[DaniResultDetailBase] StartNumIn")

			this.numInEndTimer_ = 0

			if(this.detailType_ == 0)then
				this.allScoreFront_:SkipCounter()
				this.allScoreBack_:SkipCounter()
				this.allScoreAdd_:SkipCounter()
				this.mainMc_.dummy_detail.detail_mc.score_all_mc:GotoAndStop("init")
			else
				for idx = 1, g_maxReachNum_ do
					this.detailScoreFront_[idx]:SkipCounter()
					this.detailScoreBack_[idx]:SkipCounter()
					this.detailScoreAdd_[idx]:SkipCounter()
					this.scoreDeteilMc_[idx]:GotoAndStop("init")
				end
			end
		end,

		UpdateCountUp = function(this)
			-- カウントアップ更新
			if(this.isGaugeCountUpEnd_ == false)then
				-- ゲージのカウントアップ中
				this:UpdateCountUpGauge()
			elseif(this.isScoreCountUpEnd_ == false)then
				-- スコアのカウントアップ中
				this:UpdateNumIn()
			end

			-- this:UpdateCountUpScore()
			-- this:UpdateCountUpGauge()
		end,

		UpdateCountUpScore = function(this)
			if(this.isScoreCountUpEnd_ == true)then
				return
			end

			-- スコアカウントアップ更新
			if(this.detailType_ == 0)then
				-- All
				this.allScoreFront_:Update()
				this.allScoreBack_:Update()
				this.allScoreAdd_:Update()

				if(this.allScoreFront_.isEnd_ == true and this.allScoreBack_.isEnd_ == true)then
					-- カウントアップ完了判定
					this.isScoreCountUp_	= false
					this.isScoreCountUpEnd_	= true
				end
			else
				-- 1st~3rd
				local countEnd = 0
				for idx = 1, g_maxReachNum_ do
					this.detailScoreFront_[idx]:Update()
					this.detailScoreBack_[idx]:Update()
					this.detailScoreAdd_[idx]:Update()

					if(this.detailScoreFront_[idx].isEnd_ == true and this.detailScoreBack_[idx].isEnd_)then
						countEnd = countEnd + 1
					end
				end

				if(countEnd == g_maxReachNum_)then
					-- カウントアップ完了判定
					this.isScoreCountUp_	= false
					this.isScoreCountUpEnd_	= true
				end
			end
		end,

		UpdateNumIn = function(this)
			if(this.detailType_ == 0)then
				-- All
				if(this.mainMc_.dummy_detail.detail_mc.score_all_mc:IsInCurrentLabelMc("" ,"init"))then
					-- 開始
					this.mainMc_.dummy_detail.detail_mc.score_all_mc:GotoAndPlay("num_in")
					-- 大成功演出
					local flag = this:CheckMax(this.gaugeType_, this.odaiNum_[1], this.odaiGoodBorder_[1])
					-- ゲージの色を更新
					this:GaugeColorChange(this.mainMc_.dummy_detail.detail_mc.score_all_mc.score_l_gauge_bar_mc, this.currentGauge_, this.gaugeType_, flag, this.odaiGaugeGoodBorder_[1])
					--if(flag == true)then
					--	-- 大成功
					--	gaugeMaxType = this.mainMc_.dummy_detail.detail_mc.score_all_mc.score_l_gauge_bar_mc
					--	gaugeMaxType:GotoAndPlay("max_start")
					--end

					TSound:Play("se_daniresult_v12e","gauge_judgement")			-- SE

				elseif(this.mainMc_.dummy_detail.detail_mc.score_all_mc:IsInCurrentLabelMc("" ,"num_in"))then
					-- 更新中

				elseif(this.mainMc_.dummy_detail.detail_mc.score_all_mc:IsInCurrentLabelMc("" ,"wait"))then
					-- 完了
					this.numInEndTimer_ = this.numInEndTimer_+1
					if( this.numInEndTimer_ < this.kNumInWait_ )then
						return
					end

					this.isScoreCountUp_	= false
					this.isScoreCountUpEnd_	= true
				end

			else
				-- 1st~3rd
				local countEnd = 0
				for idx = 1, g_maxReachNum_ do
					if(this.scoreDeteilMc_[idx]:IsInCurrentLabelMc("" ,"init"))then
						-- 開始
						this.scoreDeteilMc_[idx]:GotoAndPlay("num_in")

						-- 大成功演出
						local flag = this:CheckMax(this.gaugeType_, this.odaiNum_[idx], this.odaiGoodBorder_[idx])
						-- ゲージの色を更新
						this:GaugeColorChange(this.scoreDeteilMc_[idx].score_m_gauge_bar_mc, this.detailCurrentGauge_[idx], this.gaugeType_, flag, this.odaiGaugeGoodBorder_[idx])
						--if(flag == true)then
						--	-- 大成功
						--	gaugeMaxType = this.scoreDeteilMc_[idx].score_m_gauge_bar_mc
						--	gaugeMaxType:GotoAndPlay("max_start")
						--end

						TSound:Play("se_daniresult_v12e","gauge_judgement")			-- SE

						return
					elseif(this.scoreDeteilMc_[idx]:IsInCurrentLabelMc("" ,"num_in"))then
						-- 更新中
						return
					elseif(this.scoreDeteilMc_[idx]:IsInCurrentLabelMc("" ,"wait"))then
						-- 完了
						if(this.numInEndTimer_ < (this.kNumInWait_*idx))then
							this.numInEndTimer_ = this.numInEndTimer_+1
							return
						end
					end

					countEnd = countEnd + 1
				end

				if(countEnd == g_maxReachNum_)then
					-- カウントアップ完了判定
					this.isScoreCountUp_	= false
					this.isScoreCountUpEnd_	= true
				end
			end
		end,

		ScoreSkip = function(this)
			Debug.PrintString("[DaniResultDetailBase] ScoreSkip")
			if(this.detailType_ == 0)then
				this.allScoreFront_:SkipCounter()
				this.allScoreBack_:SkipCounter()
				this.allScoreAdd_:SkipCounter()
				this.mainMc_.dummy_detail.detail_mc.score_all_mc:GotoAndStop("wait")
			else
				for idx = 1, g_maxReachNum_ do
					this.detailScoreFront_[idx]:SkipCounter()
					this.detailScoreBack_[idx]:SkipCounter()
					this.detailScoreAdd_[idx]:SkipCounter()
					this.scoreDeteilMc_[idx]:GotoAndStop("wait")
				end
			end

			-- カウントアップ完了判定
			this.isScoreCountUp_	= false
			this.isScoreCountUpEnd_	= true
		end,

		UpdateCountUpGauge = function(this)
			-- ゲージカウントアップ更新
			if(this.detailType_ == 0)then
				this:UpdateGaugeAll()
			else
				this:UpdateGauge()
			end
		end,

		UpdateGaugeAll = function(this)
			-- allゲージの更新
			if(this.isGaugeCountUpEnd_ == true)then
				return
			end

			-- SEの更新
			if(TSound:IsPlayingSlot(0) == false)then
				--TSound:PlaySlot("se_daniresult_v12e","gauge_up_loop", 0)		-- SE
			end

			if(this.gauge_ == this.currentGauge_)then
				-- ゲージの更新完了
				Debug.PrintString("UpdateGaugeAll Finish")

				-- 大成功演出
				-- CheckMax = function(this, gaugeType, odaiNum, GoodBorder)
				local flag = this:CheckMax(this.gaugeType_, this.odaiNum_[1], this.odaiGoodBorder_[1])

				-- ゲージに合わせたスコアの色を更新
				this:ScoreColorChange(this.scoreMc_.score_l_gauge_num_mc, this.currentGauge_, this.gaugeType_, flag, this.odaiGaugeGoodBorder_[1])

				-- ゲージの色を更新
				this:GaugeColorChange(this.mainMc_.dummy_detail.detail_mc.score_all_mc.score_l_gauge_bar_mc, this.currentGauge_, this.gaugeType_, false, this.odaiGaugeGoodBorder_[1])

				--if( flag == true)then
				--	-- ゲージを大成功に変更
				--	gaugeMaxType = this.mainMc_.dummy_detail.detail_mc.score_all_mc.score_l_gauge_bar_mc
				--	gaugeMaxType:GotoAndPlay("max_start")
				--end

				TSound:StopSlot(0)
				this.isGaugeCountUp_	= false
				this.isGaugeCountUpEnd_	= true
				return
			end
	
			this.isGaugeCountUp_ = true
			this.gaugeTimer_ = this.gaugeTimer_ + 1
			if(this.gaugeTimer_ > this.kGaugeSpeed_)then
	
				-- ゲージ増加
				this.gaugeTimer_ = 0

				if(this.gaugeType_ == 0)then
					-- type_up
					this.currentGauge_ = this.currentGauge_ + 1
				else
					-- type_down
					this.currentGauge_ = this.currentGauge_ - 1
				end
				this.gaugeMc_:GotoAndStop("gauge_"..this.currentGauge_)

				-- ゲージに合わせたスコアの色を更新
				this:ScoreColorChange(this.scoreMc_.score_l_gauge_num_mc, this.currentGauge_, this.gaugeType_, false, this.odaiGaugeGoodBorder_[1])

				-- ゲージの色を更新
				this:GaugeColorChange(this.mainMc_.dummy_detail.detail_mc.score_all_mc.score_l_gauge_bar_mc, this.currentGauge_, this.gaugeType_, false, this.odaiGaugeGoodBorder_[1])

				--if(this.currentGauge_ == this.kGaugeMax_)then
				--	-- ゲージが最大
				--	if(this.isGaugeMax_ == false)then
				--		this.isGaugeMax_ = true
				--	end
				--end
			end
		end,

		UpdateGauge = function(this)
			-- 各詳細ゲージの更新
			local countEnd = 0

			-- SEの更新
			if(TSound:IsPlayingSlot(0) == false)then
				--TSound:PlaySlot("se_daniresult_v12e","gauge_up_loop", 0)		-- SE
			end

			for idx = 1, g_maxReachNum_ do
				if(this.detailGauge_[idx] == this.detailCurrentGauge_[idx])then
					-- ゲージの更新完了
					countEnd = countEnd+1

					-- 大成功演出
					-- CheckMax = function(this, gaugeType, odaiNum, GoodBorder)
					local flag = this:CheckMax(this.gaugeType_, this.odaiNum_[idx], this.odaiGoodBorder_[idx])

					-- ゲージに合わせたスコアの色を更新
					this:ScoreColorChange(this.scoreDeteilMc_[idx].score_m_gauge_num_mc, this.detailCurrentGauge_[idx], this.gaugeType_, flag, this.odaiGaugeGoodBorder_[idx])

					-- ゲージの色を更新
					this:GaugeColorChange(this.scoreDeteilMc_[idx].score_m_gauge_bar_mc, this.detailCurrentGauge_[idx], this.gaugeType_, false, this.odaiGaugeGoodBorder_[idx])

					--if( flag == true)then
					--	-- 大成功
					--	gaugeMaxType = this.scoreDeteilMc_[idx].score_m_gauge_bar_mc
					--	gaugeMaxType:GotoAndPlay("max_start")
					--end
				else
					this.detailGaugeTimer_[idx] = this.detailGaugeTimer_[idx] + 1
					if(this.detailGaugeTimer_[idx] > this.kGaugeSpeed_)then
						this.detailGaugeTimer_[idx] = 0
		
						-- ゲージ増加
						if(this.gaugeType_ == 0)then
							-- type_up
							this.detailCurrentGauge_[idx] = this.detailCurrentGauge_[idx] + 1
						else
							-- type_down
							this.detailCurrentGauge_[idx] = this.detailCurrentGauge_[idx] - 1
						end
						this.gaugeDeteilMc_[idx]:GotoAndStop("gauge_"..this.detailCurrentGauge_[idx])

						-- ゲージに合わせたスコアの色を更新
						this:ScoreColorChange(this.scoreDeteilMc_[idx].score_m_gauge_num_mc, this.detailCurrentGauge_[idx], this.gaugeType_, false, this.odaiGaugeGoodBorder_[idx])

						-- ゲージの色を更新
						this:GaugeColorChange(this.scoreDeteilMc_[idx].score_m_gauge_bar_mc, this.detailCurrentGauge_[idx], this.gaugeType_, false, this.odaiGaugeGoodBorder_[idx])
		
						--if(this.detailCurrentGauge_[idx] == this.kGaugeMax_)then
						--	-- ゲージが最大
						--	if(this.isGaugeMax_ == false)then
						--		this.isGaugeMax_ = true
						--	end
						--end
					end	
				end
			end

			if(countEnd == g_maxReachNum_)then
				-- カウントアップ完了判定
				TSound:StopSlot(0)
				this.isGaugeCountUp_		= false
				this.isGaugeCountUpEnd_		= true
			end

		end,

		GaugeSkip = function(this)
			-- ゲージスキップ演出時
			Debug.PrintString("[DaniResultDetailBase] GaugeSkip")
			if(this.detailType_ == 0)then
				this.currentGauge_ = this.gauge_
				this.gaugeMc_:GotoAndStop("gauge_"..this.currentGauge_)

				-- CheckMax = function(this, gaugeType, odaiNum, GoodBorder)
				local flag = this:CheckMax(this.gaugeType_, this.odaiNum_[1], this.odaiGoodBorder_[1])

				-- ゲージに合わせたスコアの色を更新
				this:ScoreColorChange(this.scoreMc_.score_l_gauge_num_mc, this.currentGauge_, this.gaugeType_, flag, this.odaiGaugeGoodBorder_[1])

				-- ゲージの色を更新
				this:GaugeColorChange(this.mainMc_.dummy_detail.detail_mc.score_all_mc.score_l_gauge_bar_mc, this.currentGauge_, this.gaugeType_, flag, this.odaiGaugeGoodBorder_[1])

				-- 大成功演出
				--if(flag == true)then
				--	-- 大成功
				--	gaugeMaxType = this.mainMc_.dummy_detail.detail_mc.score_all_mc.score_l_gauge_bar_mc
				--	gaugeMaxType:GotoAndPlay("max_start")
				--end
			else
				Debug.PrintString("[DaniResultDetailBase] ")
				for idx = 1, g_maxReachNum_ do
					this.detailCurrentGauge_[idx] = this.detailGauge_[idx]
					this.gaugeDeteilMc_[idx]:GotoAndStop("gauge_"..this.detailCurrentGauge_[idx])

					-- CheckMax = function(this, gaugeType, odaiNum, GoodBorder)
					local flag = this:CheckMax(this.gaugeType_, this.odaiNum_[idx], this.odaiGoodBorder_[idx])

					-- ゲージに合わせたスコアの色を更新
					this:ScoreColorChange(this.scoreDeteilMc_[idx].score_m_gauge_num_mc, this.detailCurrentGauge_[idx], this.gaugeType_, flag, this.odaiGaugeGoodBorder_[idx])

					-- ゲージの色を更新
					this:GaugeColorChange(this.scoreDeteilMc_[idx].score_m_gauge_bar_mc, this.detailCurrentGauge_[idx], this.gaugeType_, flag, this.odaiGaugeGoodBorder_[idx])

					-- 大成功演出
					--if(flag == true)then
					--	-- 大成功
					--	gaugeMaxType = this.scoreDeteilMc_[idx].score_m_gauge_bar_mc
					--	gaugeMaxType:GotoAndPlay("max_start")
					--end
				end
			end

			-- ゲージカウント完了
			TSound:StopSlot(0)
			this.isScoreCountUp_		= false
			this.isScoreCountUpEnd_		= true
		end,

		-- ゲージの色設定 : empty/up_50/up_80/up_100/down_80/down_100/max
		GaugeColorChange = function(this, mc, gaugeNum, gaugeType, isMax, goodGauge)
			-- ゲージの色を変更
			if(isMax == true)then
				-- 大成功
				mc:GotoAndPlay("max_start")
				return
			end

			if(gaugeType == 0)then
				-- 0から増えていくゲージ
				if(gaugeNum == 0)then
					mc:GotoAndStop("empty")
				elseif(gaugeNum >= 1 and gaugeNum <= 50)then
					mc:GotoAndStop("up_50")
				elseif(gaugeNum >= 51 and gaugeNum <= 95)then
					mc:GotoAndStop("up_80")
				elseif(gaugeNum >= 96 and gaugeNum <= 100)then
					mc:GotoAndStop("up_100")
				end
			else
				-- 100から減っていくゲージ
				if(gaugeNum == 0)then
					mc:GotoAndStop("empty")
				elseif(gaugeNum >= 1 and gaugeNum < 30)then
					mc:GotoAndStop("down_80")
				elseif(gaugeNum >= 30 and gaugeNum <= goodGauge)then
					mc:GotoAndStop("up_80")
				elseif(gaugeNum > goodGauge and gaugeNum <= 100)then
					mc:GotoAndStop("down_100")
				end
			end
		end,

		-- 数値の色設定 : empty/up_50/up_80/up_100/down_80/down_100/max
		ScoreColorChange = function(this, mc, gaugeNum, gaugeType, isMax, goodGauge)
			-- ゲージの色を変更
			if(isMax == true)then
				-- 大成功
				mc:GotoAndStop("max")
				return
			end

			if(gaugeType == 0)then
				-- 0から増えていくゲージ
				if(gaugeNum == 0)then
					mc:GotoAndStop("empty")
				elseif(gaugeNum >= 1 and gaugeNum <= 50)then
					mc:GotoAndStop("up_50")
				elseif(gaugeNum >= 51 and gaugeNum <= 95)then
					mc:GotoAndStop("up_80")
				elseif(gaugeNum >= 96 and gaugeNum <= 100)then
					mc:GotoAndStop("up_100")
				end
			else
				-- 100から減っていくゲージ
				if(gaugeNum == 0)then
					mc:GotoAndStop("empty")
				elseif(gaugeNum >= 1 and gaugeNum < 30)then
					mc:GotoAndStop("down_80")
				elseif(gaugeNum >= 30 and gaugeNum <= goodGauge)then
					mc:GotoAndStop("up_80")
				elseif(gaugeNum > goodGauge and gaugeNum <= 100)then
					mc:GotoAndStop("down_100")
				end
			end
		end,

		-- 大成功チェック: true:大成功, false:大成功ではない
		CheckMax = function(this, gaugeType, odaiNum, GoodBorder)
			if(gaugeType == 0)then
				if(odaiNum >= GoodBorder)then
					return true
				end
			else
				if(odaiNum < GoodBorder)then
					return true
				end
			end

			return false
		end,

		-- 不合格, 合格, 大成功の判定
		-- 0:不合格, 1:合格, 2:大成功合格
		CheckResult = function(this)
			if(g_maxReachNum_ ~= 3)then
				-- 3曲分到達できなかった場合、未到達
				return 0
			end

			local bad		= 0		-- 不合格
			local ok		= 0		-- 成功
			local good		= 0		-- 大成功
		
			-- 不合格, 成功, 大成功の判定
			if(this.detailType_ == 0)then
				-- ゲージ1つ分の判定
				if(this.gaugeType_ == 0)then
					-- 0から増えるゲージ
					if(this.odaiNum_[1] >= this.odaiBorder_[1])then
						-- 成功ラインを超えている
						if(this.odaiNum_[1] >= this.odaiGoodBorder_[1])then
							-- 大成功ラインを超えている
							return 2
						end
						return 1
					end
					return 0
				else
					-- 100から減るゲージ
					if(this.odaiNum_[1] <= this.odaiBorder_[1])then
						-- 成功ラインを超えている
						if(this.odaiNum_[1] <= this.odaiGoodBorder_[1])then
							-- 大成功ラインを超えている
							return 2
						end
						return 1
					end
					return 0
				end
			else
				-- ゲージ3つ分の判定
				if(this.gaugeType_ == 0)then
					-- 0から増えるゲージ
					for idx = 1, 3 do
						if(this.odaiNum_[idx] >= this.odaiBorder_[idx])then
							-- 成功ラインを超えている
							if(this.odaiNum_[idx] >= this.odaiGoodBorder_[idx])then
								-- 大成功ラインを超えている
								good = good+1
							else
								ok = ok+1
							end
						end
					end

					-- 判定
					if(good == 3)then
						return 2
					end

					if((ok + good) == 3)then
						return 1
					end
					
					return 0
				else
					-- 100から減るゲージ
					for idx = 1, 3 do
						if(this.odaiNum_[idx] <= this.odaiBorder_[idx])then
							-- 成功ラインを超えている
							if(this.odaiNum_[idx] <= this.odaiGoodBorder_[idx])then
								-- 大成功ラインを超えている
								good = good+1
							else
								ok = ok+1
							end
						end
					end

					-- 判定
					if(good == 3)then
						return 2
					end
					
					if((ok + good) == 3)then
						return 1
					end

					return 0
					
				end
			end
		end,

		-- gaugeType_			= 0,	-- ゲージのタイプ(0:type_up, 1:type_down)
		-- detailNum_			= 0,	-- 詳細スコアの番号 : 1～3
		-- detailType_			= 0,	-- お題の種類 : 0:3曲累計, 1:1曲目, 2:2曲目, 3:3曲分
		-- clearType_			= {},	-- お題のクリア条件
		-- odaiBorder_			= {},	-- お題の成功ライン
		-- odaiGoodBorder_		= {},	-- お題の大成功ライン
		-- odaiNum_				= {},	-- お題に対する成績

	}
end