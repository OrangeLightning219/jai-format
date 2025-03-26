test :: ()
{
    can_be_used = skill_info.can_interrupt_other_skills &&
    (current_skill.current_duration <= 
                current_skill.info.time_to_interrupt);
}
