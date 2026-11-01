-- CopyRight.lua
-- 権利表記画面

-- 対応するlumenファイル
UseLumenFile = "lumen/000_default/attract/copyright"

-- 使うクラスを読み込む
require("common.State")

-- 初期化処理
function Init()
	-- シーケンス
	CopyRightScene = State.New("CopyRight")

	-- ステートマシン構築
	CopyRightScene.func_["Begin"] = function()
		-- ムービークリップ
		CopyRightScene.main_mc_ = Lumen.GetMovieClip("copyright_instance_0",true)
		-- １フレーム目から再生
		CopyRightScene.main_mc_:GotoAndPlay(1)

		-- テキストの指定
		CopyRightScene.main_mc_:SetText("text_instance_0","text01","copyright_01")
		CopyRightScene.main_mc_:SetText("text_instance_0","text02","copyright_02")
		CopyRightScene.main_mc_:SetText("text_instance_1","text01","copyright_03")
		CopyRightScene.main_mc_:SetText("text_instance_1","text02","copyright_04")

		CopyRightScene:SetState("Main")

		CopyRightScene.now_page_ = 1
	end

	CopyRightScene.func_["Main"] = function()
		-- メニューテスト以外
		if(IsFromMenuTest == false) then
			-- 再生終了で次へ
			if(CopyRightScene.main_mc_:IsPlay() == false) then
				CopyRightScene:SetState("EndWait")
			end
		end
	end

	CopyRightScene.func_["EndWait"] = function()
		-- シーン終了
		Common.LuaFinish()
		CopyRightScene:SetState("End")
	end

	CopyRightScene.func_["End"] = function()
	end
end

-- 毎フレームの処理
function Proc()
	-- ステート処理
	CopyRightScene:Update()
end

