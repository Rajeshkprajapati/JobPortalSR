using System.Collections.Generic;

namespace JobPortal.Model.DataViewModel.Shared
{
    public class BulkJobPostSummaryViewModel
    {
        public string FileName { get; set; }
        public IList<BulkJobPostSummaryDetailViewModel> Summary { get; set; }
    }
}
