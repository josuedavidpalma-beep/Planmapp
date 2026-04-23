$Uri1 = "https://pthiaalrizufhlplbjht.supabase.co/rest/v1/payment_trackers?select=id,plan_id,bill_id,user_id,guest_name,amount_owe,amount_paid,status,description,created_at,plans(creator_id)"
$Uri2 = "https://pthiaalrizufhlplbjht.supabase.co/rest/v1/expenses"
$Headers = @{
    apikey = "***"
    Authorization = "Bearer ***"
}
Invoke-RestMethod -Uri $Uri1 -Method Get -Headers $Headers | Select-Object -First 2 | ConvertTo-Json -Depth 5
Invoke-RestMethod -Uri $Uri2 -Method Get -Headers $Headers | Select-Object -First 2 | ConvertTo-Json -Depth 5
