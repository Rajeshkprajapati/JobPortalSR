using System.Collections.Generic;

namespace JobPortal.Model.DataViewModel.Shared
{
    public class BulkUploadSummaryViewModel<T>
    {
        public string FileName { get; set; }
        public IList<T> Summary { get; set; }
    }
}
