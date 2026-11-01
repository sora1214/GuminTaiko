-- タイマー表示
Timer = {}
function Timer.New(InstanceName)
	return
	{
		instance_name_ = InstanceName,
		red_limit_ = 0,
		now_count_ = 0,
		now_count_decimal_ = 0,
		now_play_ = false,
		use_voice_ = false,
		use_se_ = false,
		voice_slot_no_ = -1,

		LoadMovie = function(this)
			Lumen.LoadMovie("lumen/000_default/common/timer",this.instance_name_)
		end,
		-- 初期化
		Setup = function(this,red_limit)
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
				this.mc_ = Lumen.GetMovieClip(this.instance_name_,true)
				this.counter_mc_ = this.mc_.timer_main_instance.time_count_instance
			end
			this.red_limit_ = red_limit
			this.now_count_decimal_ = Common.FPS
			this.now_play_ = false
		end,
		-- 表示ON/OFF
		SetVisible = function(this,flag)
			this.mc_:SetVisible(flag)
		end,
		-- 影表示ON/OFF
		SetShadow = function(this,flag)
			this.counter_mc_.shadow:SetVisible(flag)
		end,
		-- サウンド設定
		SoundSetting = function(this,voiceflag,seflag)
			this.use_voice_ = voiceflag
			this.use_se_ = seflag
		end,
		-- サウンドのボイスのスロットNo設定（無設定ならデフォルト-1でスロット指定なし）
		SetSoundVoiceSlotNo = function( this, voice_slot_no )
			this.voice_slot_no_ = voice_slot_no
		end,
		-- 数字設定
		SetCount = function(this,count)
			this.now_count_ = count

			-- 表示調整
			this:DisplayCount()
		end,
		-- 数字設定(decimalも同時に設定)
		SetCountAndDecimal = function(this,count,count_decimal)
			this.now_count_         = count
			this.now_count_decimal_ = count_decimal

			-- 表示調整
			this:DisplayCount()
		end,
		-- 数字取得
		GetCount = function(this)
			return this.now_count_
		end,
		-- カウント開始
		StartCount = function(this)
			this.now_play_ = true
			this.now_count_decimal_ = Common.FPS
		end,
		-- カウント停止
		StopCount = function(this)
			this.now_play_ = false
		end,
		-- ゼロか？
		IsZero = function(this)
			if(this.now_count_ == 0) then
				return true
			end
			return false
		end,
		-- 動作しているか
		IsPlay = function(this)
			return this.now_play_
		end,
		-- 更新
		Update = function(this)
			if(this.now_play_ == true) then
				this.now_count_decimal_ = this.now_count_decimal_ - 1
				if(this.now_count_decimal_ == 0) then
					this.now_count_decimal_ = Common.FPS
					this.now_count_ = this.now_count_ - 1
					this:DisplayCount()

					-- サウンド関連
					local play_voice = false
					if(this.use_voice_ == true) then
						-- ボイスのスロットが有効で再生中の再生開始時は停止する
						if ( ( ( this.now_count_ == 10 ) or ( this.now_count_ == 5 ) ) and ( 0 <= this.voice_slot_no_ ) ) then
							if ( TSound:IsPlayingSlot( this.voice_slot_no_ ) ) then
								TSound:StopSlot( this.voice_slot_no_ )
							end
						end
						if(this.now_count_ == 30) then
							-- ボイスＳＥ「あと３０秒！」」
							TSound:PlaySlot("voice_common_v12a","timer_30sec", this.voice_slot_no_)
						end
						if(this.now_count_ == 10) then
							-- ボイスＳＥ「あと１０秒！」」
							TSound:PlaySlot("voice_common_v12a","timer_10sec", this.voice_slot_no_)
						end
						if(this.now_count_ == 5) then
							-- ボイスＳＥ「あと５秒！」」
							TSound:PlaySlot("voice_common_v12a","timer_05sec", this.voice_slot_no_)
						end
					end
					if((this.use_se_ == true) and (play_voice == false)) then
						if(this.now_count_ <= this.red_limit_) then
							-- ＳＥ「ピ」
							TSound:Play("se_common_v12a","timer_count")
						end
					end

					-- 0になったら止めちゃうよ
					if(this.now_count_ == 0) then
						-- ボイスのスロットが有効で発生中の時は停止
						if ( 0 <= this.voice_slot_no_ ) then
							if ( TSound:IsPlayingSlot( this.voice_slot_no_ ) ) then
								TSound:StopSlot( this.voice_slot_no_ )
							end
						end
						this:StopCount()
					end
				end
			end
		end,
		-- 表示調整
		DisplayCount = function(this)
			local disp_count = this.now_count_
			if(disp_count > 999) then
				disp_count = 999
			end

			-- 桁
			local disp_count_0 = (disp_count % 10)
			local disp_count_1 = math.floor((disp_count % 100) / 10)
			local disp_count_2 = math.floor((disp_count % 1000) / 100)

			if(disp_count > 99) then
				this.counter_mc_.counter_instance:GotoAndStop("num3")

				this.counter_mc_.counter_instance.digit2:GotoAndStop("_"..disp_count_2)
				this.counter_mc_.counter_instance.digit1:GotoAndStop("_"..disp_count_1)
				this.counter_mc_.counter_instance.digit0:GotoAndStop("_"..disp_count_0)
			elseif(disp_count > 9) then
				this.counter_mc_.counter_instance:GotoAndStop("num2")

				this.counter_mc_.counter_instance.digit1:GotoAndStop("_"..disp_count_1)
				this.counter_mc_.counter_instance.digit0:GotoAndStop("_"..disp_count_0)
			elseif(disp_count > this.red_limit_) then
				this.counter_mc_.counter_instance:GotoAndStop("num1")

				this.counter_mc_.counter_instance.digit0:GotoAndStop("_"..disp_count_0)
			else
				this.counter_mc_.counter_instance:GotoAndStop("num1_effect")

				this.counter_mc_.counter_instance.digit0_effect.body:GotoAndStop("_"..disp_count_0)
				this.counter_mc_.counter_instance.digit0_effect:Play()
			end
		end,
	}
end

