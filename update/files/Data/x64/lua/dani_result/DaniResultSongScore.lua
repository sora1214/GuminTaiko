-- DaniResultSongScore.lua
-- 段位リザルトスコア
DaniResultSongScore = {}

-- 使うクラスを読み込む
require("common.Sound")
require("common.State")

-- このクラス
function DaniResultSongScore.New()
	return
	{
		-- ムービークリップ
--		mc_ = McInstance,

		-- インスタンス

		kRollEndTime_ = 0.5*Common.FPS,		-- 値が固まるまでにロールし続ける時間
		
		targetNum_ = 0,			-- 表示したい値
		targetDigit_ = 0,		-- 表示したい値の桁数
		currentDigit_ = 0,		-- 現在ロールしている桁数
		currentTime_ = 0,		-- 現在ロールしている時間
		maxDigit_ = 0,			-- 最大桁数
		targetDigitNum_ = {},	-- 表示したい数値をケタごとにバラし、１の位を先頭に格納
	
		targetMc_,
		digitMc = {},			-- 各桁の数字のMC
	
		-- フラグ
		isStart_ = false,
		isEnd_ = false,
	
	
		Init = function(this, targetmc, maxdigit, targetnum)
			Debug.PrintString("[DaniResultSongScore] Init")
			Debug.PrintString("maxdigit:"..maxdigit)
			Debug.PrintString("targetnum:"..targetnum)
			this.targetMc_ = targetmc	
			this.maxDigit_ = maxdigit
			this.targetNum_ = targetnum
			
			-- 桁数を設定
			this.targetMc_:GotoAndStop("digit"..this.maxDigit_)

			-- 各桁の数字のMCを変数に格納
			for idx = 0,this.maxDigit_ - 1	do
				this.digitMc[idx] = this.targetMc_:GetChildMc("digit"..idx + 1, true)
				--this.digitMc[idx]:GotoAndStop("num0")
				this.digitMc[idx]:GotoAndStop("none")
			end
		end,
	
	
		Update = function(this)
			if (this.isStart_ == true and this.isEnd_ == false) then
				this:NumCounter()
			end
		end,	
		
		
		--	表示数の更新開始命令
		StartCounter = function(this)
			this.isStart_ = true
			this:SetTargetDigitNum()
		end,
		--	ここまでStartCounter

		
		
		-- カウントアップ演出をスキップした表示数の更新開始命令
		SkipCounter = function(this)
			this:SetTargetDigitNum()
			Debug.PrintString("SkipCounter:targetnum:"..this.targetNum_)
			for idx = 0,this.maxDigit_ - 1 do
				if(this.targetDigitNum_[idx] ~= -1) then
					this.digitMc[idx]:GotoAndStop("num"..this.targetDigitNum_[idx])	-- 表示数値を目的の値で止める
					this.isEnd_ = true
				end
			end
		end,
		
		
		
		-- カウントアップ演出をスキップし、受け取った値を直で表示
		DirectCounter = function(this, num)
			this.targetNum_ = num
			this:SetTargetDigitNum()
		
			for idx = 0,this.maxDigit_ - 1 do
				if(this.targetDigitNum_[idx] ~= -1) then
					this.digitMc[idx]:GotoAndStop("num"..this.targetDigitNum_[idx])	-- 表示数値を目的の値で止める
					this.isEnd_ = true
				end
			end
		end,
		
		
		
		-- targetnum を桁ごとにバラして１桁ずつ targetDigitNum_ に格納
		-- 最後の桁を格納したら -1 を格納します
		SetTargetDigitNum = function(this)
			bufferTargetNum = this.targetNum_
			digitNum = 0
			digit  = 10
			for idx = 0,this.maxDigit_ - 1 do		-- 以降は数値を桁ごとにバラす不思議な計算式
				if(idx ~= 0 and bufferTargetNum == 0) then
					this.targetDigitNum_[idx] = -1
				else
					digitNum = bufferTargetNum % digit
					bufferTargetNum = bufferTargetNum - digitNum
					this.targetDigitNum_[idx] = digitNum / (digit / 10)
					this.targetDigit_ = this.targetDigit_ + 1
				end
				digit = digit * 10
			end
		end,
		--	ここまでSetTargetDigitNum
		
		
		--	表示数の更新
		NumCounter = function(this)	
			if(this.currentTime_ == 0) then
				this.digitMc[this.currentDigit_]:GotoAndPlay("loop")-- 現在の桁値のロールを開始
				this.currentTime_ = this.currentTime_ + 1			-- タイマを１進める
			elseif (this.currentTime_ < this.kRollEndTime_) then
				this.currentTime_ = this.currentTime_ + 1			-- タイマがkRollEndTime_の値になるまで1ずつ進める
			else
				this.digitMc[this.currentDigit_]:GotoAndPlay("num"..this.targetDigitNum_[this.currentDigit_])	-- 表示数値を目的の値で止める
				this.currentDigit_ = this.currentDigit_ + 1			-- 現在の桁値を1進める
				this.currentTime_ = 0								-- タイマをリセット
			end
		
			if(this.currentDigit_ == this.maxDigit_) then			-- 現在の桁値が最大桁数に達したら実行
				this.isEnd_ = true									-- 処理を終了
			end
			if(this.targetDigitNum_[this.currentDigit_] == -1) then	-- targetDigitNum_ に -1 が格納されていたら実行
				this.isEnd_ = true									-- 処理を終了
			end
		end,
		--	ここまでNumCounter
		
	}
end
