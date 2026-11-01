-- バナー表示
Banner = {}
function Banner.New(InstanceName,isAttract,isMovie,gameMode)
	return
	{
		instance_name_ = InstanceName,
		is_attract_ = isAttract,
		is_movie_ = isMovie,
		playing_ = false,
		id_list_ = {},
		disp_index_ = 1,
		game_mode_ = gameMode,

		LoadMovie = function(this)
			if(this.is_attract_ == true) then
				Lumen.LoadMovie("lumen/000_default/common/banner",this.instance_name_)
			else
				Lumen.LoadMovie("lumen/000_default/entry/modeselect_banner",this.instance_name_)
			end
		end,
		-- 初期化
		Setup = function(this)
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
				this.mc_ = Lumen.GetMovieClip(this.instance_name_,true)

				-- IDの一覧取得
				if(this.is_attract_ == true) then
					this.id_list_ = Cabinet.AttractBanner(this.is_movie_)
				else
					this.id_list_ = Cabinet.ModeSelectBanner(this.game_mode_)
				end

				this.disp_index_ = 1
			end
		end,
		ChangeGameMode = function(this,newMode)
			this.game_mode_ = newMode
			if(this.is_attract_ == false) then
				local oldList = this.id_list_
				this.id_list_ = Cabinet.ModeSelectBanner(this.game_mode_)

				local is_change = false
				if(#oldList ~= #this.id_list_) then
					is_change = true
				else
					-- リストの中身確認
					for idx = 1,#this.id_list_ do
						if(this.id_list_[idx] ~= oldList[idx]) then
							is_change = true
						end
					end
				end
				if(is_change == true) then
					this.disp_index_ = 1
				end
			end
		end,
		-- 表示ON/OFF
		SetVisible = function(this,flag)
			this.mc_:SetVisible(flag)
		end,
		Start = function(this)
			-- バナー一覧が何もなければ表示しない
			if(#this.id_list_ == 0) then
				this:Finish()
			else
				this:SetVisible(true)
				this.mc_:GotoAndPlay("in")

				-- 最初のバナー
				this.mc_.main_instance:GotoAndPlay("id_"..this.id_list_[this.disp_index_])

				this.playing_ = true
			end
		end,
		ReStart = function(this)
			-- バナー一覧が何もなければ表示しない
			if(#this.id_list_ == 0) then
				this:Finish()
			else
				if(this.playing_ == false) then
					this:SetVisible(true)
					this.mc_:GotoAndPlay("loop")
				end
				-- 最初のバナー
				this.mc_.main_instance:GotoAndPlay("id_"..this.id_list_[this.disp_index_])
				this.playing_ = true
			end
		end,
		Finish = function(this)
			this:SetVisible(false)
			this.playing_ = false
		end,
		Update = function(this)
			if(this.playing_ == true) then
				if(this.mc_:IsPlay() == false) then
					-- バナー一覧に何もなくなったら終わらせちゃう
					if(#this.id_list_ == 0) then
						this:Finish()
					else
						-- 次のバナーは
						this.disp_index_ = this.disp_index_ + 1
						if(this.disp_index_ > #this.id_list_) then
							this.disp_index_ = 1
						end

						-- 再生しなおし
						this.mc_:GotoAndPlay("loop")
						this.mc_.main_instance:GotoAndPlay("id_"..this.id_list_[this.disp_index_])
					end
				end
			end
		end
	}
end
