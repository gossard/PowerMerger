class PowerMergerUtils {

    hidden PowerMergerUtils() {}

    static [object]GetNestedPropertyValue([object]$BaseObject, [string]$PropertyPath) {
        if($null -eq $BaseObject -or [string]::IsNullOrWhiteSpace($PropertyPath)) {
            return $null
        }
        [string[]]$Properties = $PropertyPath.Split('.')
        [object]$CurrentObject = $BaseObject
        foreach($Property in $Properties) {
            if($null -eq $CurrentObject) {
                return $null
            }
            $PropertyInfo = $CurrentObject.psobject.Properties[$Property]
            if($null -eq $PropertyInfo) {
                return $null
            }
            $CurrentObject = $PropertyInfo.Value
        }
        return $CurrentObject
    }

}