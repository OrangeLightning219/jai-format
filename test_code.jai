test :: () 
{
    result := ( ( source_is_damage && `source.damage == damage ) || 
                ( !source_is_damage && `source.surface == `source_surface ) ) && 
              is_set( `target_props, props ) || 
              ( `target == damage_surface && is_set( `source_props, props ) );


}
