
UseLumenFile = "lumen/000_default/entry/entry"
--UseLumenFile = "lumen/000_default/result/result"
--UseLumenFile = "lumen/999_kaihatsu/test03"


Main = {
    lumen_loaded_         = false,
--    lumen_movieclip_name_ = "taiko_select_instance",
    lumen_movieclip_name_ = "mode_select_instance/mode_select_list_instance/kanban_1",
--    lumen_movieclip_name_    = "main",
--    lumen_movieclip_name_    = "test_instance",
--    lumen_mc_      =,
--    lumen_main_mc_ =,

    Init = function( this )
--        Lumen.LoadMovie( "lumen/999_kaihatsu/test03", lumen_movieclip_name_ )
        this.mode_ = 0
    end,

    Proc = function( this )
        if ( this.mode_ == 0 ) then
--            Lumen.LoadMovie( "lumen/999_kaihatsu/test03", this.lumen_movieclip_name_ )
            Lumen.LoadMovie( "lumen/000_default/result/result_qrcode_image_l", this.lumen_movieclip_name_ )
            this.mode_ = 1
        else
            if ( ( this.lumen_loaded_ == false ) and ( Lumen.IsLoadMovieFinish() == true ) ) then
                -- ムービークリップ取得
                this.lumen_loaded_ = true
                this.lumen_mc_ = Lumen.GetMovieClip( this.lumen_movieclip_name_, true )
--            this.lumen_main_ = this.lumen_mc_.main_mc
                -- C側に準備完了通知
                Common.LuaPrepareFinish()
            end
        end

    end,
}




-- 初期化処理
function Init()
    Main:Init()
end

-- 毎フレームの処理
function Proc()
    Main:Proc()
end



