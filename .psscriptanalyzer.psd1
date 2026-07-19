@{
    Rules = @{
        PSAvoidLongLines = @{
            Enable = $true
            MaximumLineLength = 140
        }
    }
    IncludeRules = @(
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSAvoidLongLines'
    )
}
