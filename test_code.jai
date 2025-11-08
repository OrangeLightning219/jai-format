test :: ( a: int, b: float ) -> bool
{
	if ( c > 0.1 && c < 0.5 ) ||
	   ( c > 0.6 && c < 1.0 ) && ( a == b ||
								   c == d )
	{
		return false;
	}
}
