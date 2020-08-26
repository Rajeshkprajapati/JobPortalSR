using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;
using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Utility.Helpers
{
    public class ContractSerializer
    {
        public static JsonSerializerSettings JsonInPascalCase()
        {
            return new JsonSerializerSettings
            {
                ContractResolver = new DefaultContractResolver()
            };
        }
    }
}
