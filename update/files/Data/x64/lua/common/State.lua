-- ステートマシンのクラス、後で外に出そうか
State = {}
function State.New(name)
	return
	{
		name_ = name,
		state_ = "Begin",
		count_ = 0,
		func_ = {},
		Update = function(this)
			this.count_ = this.count_ + 1
			-- 型チェック、重いかも
			if(type(this.func_[this.state_]) == "function") then
				this.func_[this.state_]()
			else
				Debug.PrintString("Error:::State function "..this.state_.." is not function...")
			end
		end,
		SetState = function(this,newState)
			Debug.PrintString("["..this.name_.."] "..this.state_.."->"..newState)
			this.state_ = newState
			this.count_ = 0
		end,
		CheckState = function(this,iState)
			if(this.state_ == iState) then
				return true
			end
			return false
		end,
	}
end
