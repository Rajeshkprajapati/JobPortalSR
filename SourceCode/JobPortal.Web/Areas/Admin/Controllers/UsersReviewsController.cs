﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using JobPortal.Business.Interfaces.Admin;
using JobPortal.Model.DataViewModel.Admin.UsersReviews;
using JobPortal.Model.DataViewModel.Shared;
using JobPortal.Utility.Exceptions;
using JobPortal.Utility.ExtendedMethods;
using JobPortal.Utility.Helpers;
using JobPortal.Web.Filters;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace JobPortal.Web.Areas.Admin.Controllers
{
    [Area("Admin")]
    [Route("[controller]")]
    [HandleExceptionsAttribute]
    [UserAuthentication("Admin")]
    public class UsersReviewsController : Controller
    {
        private readonly IUsersReviewsHandler _usersReviewsHandler;
        public UsersReviewsController(IUsersReviewsHandler usersReviewsHandler)
        {
            _usersReviewsHandler = usersReviewsHandler;
        }

        [HttpGet]
        [Route("[action]")]
        public PartialViewResult UsersReviews()
        {
            List<UsersReviewsViewModel> list = new List<UsersReviewsViewModel>();
            try
            {
                list = _usersReviewsHandler.GetUsersReviews();
            }
            catch (DataNotFound ex)
            {
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            return PartialView("UsersReviews", list);
        }
        [HttpGet]
        [Route("[action]")]
        public IActionResult DeleteUsersReview(string Id)
        {
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);

            var result = _usersReviewsHandler.DeleteUsersReviews(Id, Convert.ToString(user.UserId));
            if (result)
            {
                //return View();
                return Json("Record Deleted");
            }
            return Json("Record Can't be Deleted");
            //return View();
        }
        [HttpGet]
        [Route("[action]")]
        public IActionResult ApproveUser(string Id)
        {
            var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);

            var result = _usersReviewsHandler.ApproveUsers(Id, Convert.ToString(user.UserId));
            if (result)
            {
                //return View();
                return Json("Record approved");
            }
            return Json("Record could not approved");
            //return View();
        }

        [HttpPost]
        [Route("[action]")]
        public JsonResult UpdateUserReview([FromBody]UsersReviewsViewModel model)
        {
            try
            {
                var user = HttpContext.Session.Get<UserViewModel>(Constants.SessionKeyUserInfo);

                var data = _usersReviewsHandler.UpdateUserReview(model,Convert.ToString(user.UserId));

                return Json(data);
            }
            catch (Exception ex)
            {
                return Json(ex.Message);
            }
        }
    }
}