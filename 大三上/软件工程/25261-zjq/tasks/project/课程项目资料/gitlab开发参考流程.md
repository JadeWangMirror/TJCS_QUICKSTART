# gitlab 开发参考流程 v2024

## REFERENCES:
1. [Always start with an issue](https://about.gitlab.com/blog/2016/03/03/start-with-an-issue/)
1. [GitLab Feature branch workflow](https://docs.gitlab.com/ee/gitlab-basics/feature_branch_workflow.html)
1. [GitLab Flow](https://docs.gitlab.com/ee/topics/gitlab_flow.html#squashing-commits-with-rebase)
1. [GitLab Git Workshop](https://docs.gitlab.com/ee/university/training/user_training.html#rebase-with-squash)
1. [Squash and Merge](https://gitlab.com/help/user/project/merge_requests/squash_and_merge)

## 介绍

项目开发 采用 feature branch workflow。 
- 首先， `master` 分支包含经过周密测试的最稳定代码，供每次汇报使用。 
- `develop` 分支基于 `master` 进行演化， 用于进行联合调试和联合测试。 
- 在基于相对完整和稳定的 `develop` 分支上，开发者们可以构建日常最常用的**特性分支（feature branch)**，并在这些分支上完成开发工作。 开发完成后，分支下游的改动逐层上传，上游集成各模块并处理各模块的冲突后，下游又拉取(pull)并迭代开发。分支演化的一个简易的示例如下所示：

```
master
├── hotfix
│   ├── hotfix_issue_123
└── develop
   ```
> **注意** 在已有的稳定版本`master`分支上发现了未预料的BUG，可从`hotfix`分支上创建新的`hotfix_issue_123`分支。

## 参考工作流
### 工作流简介
采用敏捷开发的基本工作流程，利用issue进行开发活动的管理。
- 首先，开发一个新功能前必须先撰写issue，内容采用feature模板，并对issue设置合理的Label (模块归属，讨论，ToDo等) 和计划的Due date（参考Milestone，可不完全一致）
- issue划分的参考准则是在较短的时间内<4周可完成的功能，较大的issue作为Epic或者进行拆分
- 其次，每周讨论将合理的issue分配到Doing并由Maintainer分配developer处理该issue
- Maintainer或者一名负责该issue的developer从该issue创建merge request或创建branch，并选择正确的目标分支 (develop)
    - merge request 会直接创建一个WIP merge request，并且创建一个该issue的远端分支，WIP表示该merge request还未完成
    - create branch 会创建一个该issue的远端分支
- 所有处理该issue的developer在本地创建该issue的远端分支的跟踪分支，直接在该分支上进行工作；或者继续创建该跟踪分支的子分支，完成子分支工作后merge到该跟踪分支上
- 完成工作后，maintainer负责处理该issue的merge request

### 工作流示意
1. 克隆项目:

    ```bash
    git clone https://gitlab.com/xxx.git
    ```
1. 从ISSUE创建工作分支
    - 打开想要工作的issue，点击issue右侧的Create merge request右侧的下拉按钮，命名该分支名，并选择该分支所基于的分支
    - 然后创建分支

1. 切换到所创建的模块分支

    ```bash
    git fetch origin
    git checkout -b $branch_name origin/$branch_name
    ```
1. 写代码， 提交(`commit`)修改:
    ```bash
    git status # 查看变动文件
    git add . # 添加所有修改的文件到暂存区
    git commit -am "功能实现了一点了"
    git commit -am "功能又实现了一点了"
    git commit -am "功能快实现了"
    git commit -am "功能实现了"
    ```

1. 解决与上游最新版本代码的冲突，并推送(push)分支到 GitLab:

    ```bash
    git pull # 可能要处理conflict
    git push origin $branch_name
    ```

1. 在GitLab页面上查看你的提交， 确认无误后点击网页上的按钮创建一个 merge request .

1. 团队中负责上游分支的同学查看提交的代码，并将他们合并到上游分支或主分支.

1. 通常，下游的分支应该在开始新一轮作业之前，先 pull & merge 上游分支的修改，以减少版本差异。 有时在功能分支基础上临时增加新的开发需求，临时分支可以不推送到远端，合并到功能分支后删除。

## 如何在免费的gitlab项目中使用燃尽图
使用gitlab api，参见https://www.cnblogs.com/joeye153/p/14692066.html


