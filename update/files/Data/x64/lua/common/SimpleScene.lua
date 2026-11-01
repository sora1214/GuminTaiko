-- Lumen再生待ちをして終わったらLuaを終了させるシーン
SimpleScene = {}
function SimpleScene.New(name,mcName)
	return
	{
		name_ = name,
		mc_name_ = mcName,
		state_ = "Init",
		main_mc_,
		Update = function(this)
			if(this.state_ == "Init") then
				-- 再生ムービークリップ取得
				this.main_mc_ = Lumen.GetMovieClip(this.mc_name_,true)
				-- １フレーム目から再生
				this.main_mc_:GotoAndPlay(1)
				-- 次シーケンスへ
				this.state_ = "Main"
			elseif(this.state_ == "Main") then
				-- 再生終了で次へ
				if(this.main_mc_:IsPlay() == false) then
					this.state_ = "EndWait"
				end
			elseif(this.state_ == "EndWait") then
				-- シーン終了
				Common.LuaFinish()
				this.state_ = "End"
			elseif(this.state_ == "End") then
			end
		end,
	}
end
