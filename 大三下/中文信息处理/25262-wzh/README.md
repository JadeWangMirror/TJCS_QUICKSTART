# 中文信息处理

## 课程概述

TODO

## 课程工具

TODO

## 资料结构

TODO

## 课程项目参考

本课程的核心实验是中文分词系统对比实验，完整代码与报告放在独立仓库：

- <https://github.com/hyxtj/nlp-cws-methods>

仓库基于 SIGHAN Bakeoff 2005 PKU 数据集，实现并对比四种中文分词方法：

| 方法 | 模型 |
| --- | --- |
| A | 词典最大匹配（FMM / BMM / BiMM） |
| B | 隐马尔可夫模型 HMM（BIES + Viterbi） |
| C | BiLSTM-CRF |
| D | BERT 微调（bert-base-chinese） |

仓库内容包括：

- 四种分词方法的完整实现（`method_a` ~ `method_d`）。
- 训练、评估、对比脚本。
- 交互式分词演示。
- 数据集与实验报告。

## 实验与作业

TODO

## 期末考试与复习

无期末考试，成绩主要看分词器作业、汇报以及组队大作业完成情况

## 备注

TODO
