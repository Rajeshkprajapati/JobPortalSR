using JobPortal.Data.DataModel.Admin.UserReviews;
using JobPortal.Model.DataViewModel.Admin.UsersReviews;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace JobPortal.Data.Interfaces.Admin
{
    public interface IUsersReviewsRepository
    {
        DataTable GetUsersReviews();
        bool UpdateUsersReviews(UserReviewsModel usersReviews,string userid);
        bool DeleteUsersReviews(string id, string deletedBy);
        bool ApproveUsersReviews(string id, string approvedBy);
    }
}
