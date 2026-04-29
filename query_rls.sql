SELECT relname FROM pg_class WHERE relkind = 'r' AND relnamespace = 'public'::regnamespace AND relrowsecurity = false;
