-- 〇曲１プレイ表示
NumbetOfStage = {}
function NumbetOfStage.New(InstanceName)
	return
	{
		instance_name_ = InstanceName,
		LoadMovie = function(this)
			Lumen.LoadMovie("lumen/000_default/common/numberofstage",this.instance_name_)
		end,
		Setup = function(this)
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
				this.mc_ = Lumen.GetMovieClip(this.instance_name_,true)
				-- テキスト設定
				this.mc_:SetText("number_instance","text_oneplay","attract_one_play")
				this.mc_:SetText("number_instance","text_numofstage","attract_numberofstage")

				-- 位置
				local qr_status = QR.IconStatus()
				if(qr_status == IconDispStatus.kNone) then
					this.mc_.x = (1800 - 120 - 110 - 244)
				else
					this.mc_.x = (1800 - 120 - 220 - 244)
				end

			end
		end,
	}
end

