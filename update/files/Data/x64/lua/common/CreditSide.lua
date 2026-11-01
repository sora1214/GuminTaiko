-- クレジット受付左右用表示
CreditSide = {}
function CreditSide.New(InstanceName)
	return
	{
		instance_name_ = InstanceName,

		LoadMovie = function(this)
			Lumen.LoadMovie("lumen/000_default/common/credit_player_side",this.instance_name_)
		end,
		-- 初期化
		Setup = function(this)
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
				this.mc_ = Lumen.GetMovieClip(this.instance_name_,true)

				-- テキスト設定
				this.mc_.attract_credit_instance.credit_all_instance:SetText("text_player_instance","text_player","credit_play_2p")
-- メモ 2020.01.31 Shusuke Miura attract_credit_instanceにはcredit_all_instance_2がないので削除しました。
--				this.mc_.attract_credit_instance.credit_all_instance_2:SetText("text_player_instance","text_player","credit_play_2p")
				this.mc_.attract_credit_instance.credit_all_instance:SetText("text_credit_instance","text_credit","credit_rest_2p")
--				this.mc_.attract_credit_instance.credit_all_instance_2:SetText("text_credit_instance","text_credit","credit_rest_2p")
			end
		end,
		-- 表示ON/OFF
		SetVisible = function(this,flag)
			this.mc_:SetVisible(flag)
		end,
		Start = function(this)
			this.mc_:GotoAndPlay("main")
		end
	}
end
